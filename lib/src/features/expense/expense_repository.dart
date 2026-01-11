import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../core/network/erpnext_repository.dart';
import '../../core/network/frappe_client.dart';

class ExpenseRepository extends ERPNextRepository {
  ExpenseRepository(super.client);

  @override
  String get doctype => 'Expense Claim';

  Dio get _dio => client.dio;

  /// Get expense claims for an employee
  Future<List<Map<String, dynamic>>> getEmployeeExpenses(String employeeId) async {
    try {
      return await list(
        fields: [
          'name',
          'employee',
          'employee_name',
          'posting_date',
          'total_claimed_amount',
          'total_sanctioned_amount',
          'status',
          'company',
          'expense_approver',
        ],
        filters: [
          ['employee', '=', employeeId],
        ],
        orderBy: 'posting_date desc',
        limit: 50,
      );
    } catch (e) {
      debugPrint('Error fetching expense claims: $e');
      return [];
    }
  }

  /// Get employee expenses from Journal Entry
  /// Journal Entries that have the employee's account in the accounts
  /// Optimized: Uses account-based query which is faster than party-based query
  /// Find the last two zero balance dates
  /// Returns (lastZeroDate, previousZeroDate) - the last zero balance date and the one before it
  /// If only one zero balance is found, returns (lastZeroDate, null)
  Future<({DateTime lastZeroDate, DateTime? previousZeroDate})?> _findLastTwoZeroBalanceDates(String accountName) async {
    try {
      // Query GL Entry (General Ledger) to find last zero balance
      // Sort by posting_date ascending to calculate running balance
      final glRes = await _dio.get(
        '/api/resource/GL Entry',
        queryParameters: {
          'fields': jsonEncode(['posting_date', 'debit', 'credit']),
          'filters': jsonEncode([
            ['account', '=', accountName],
            ['is_cancelled', '=', 0],
          ]),
          'order_by': 'posting_date asc',
          'limit_page_length': 1000, // Check up to 1000 entries
        },
      );

      final glEntries = (glRes.data is Map) ? (glRes.data['data'] as List?) : null;
      if (glEntries == null || glEntries.isEmpty) {
        debugPrint('No GL Entries found for account: $accountName');
        return null;
      }

      // Calculate running balance and find the LAST two zero balance dates
      double runningBalance = 0.0;
      DateTime? lastZeroDate;
      DateTime? previousZeroDate;
      
      for (final entry in glEntries) {
        if (entry is! Map) continue;
        final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
        runningBalance += (debit - credit);
        
        // If balance is zero or very close to zero (within ±10 for rounding errors), record the date
        if (runningBalance.abs() <= 10.0) {
          final dateStr = entry['posting_date'] as String?;
          if (dateStr != null) {
            try {
              final date = DateTime.parse(dateStr);
              // Update previous to last, then update last
              previousZeroDate = lastZeroDate;
              lastZeroDate = date;
            } catch (_) {
              // Skip invalid dates
            }
          }
        }
      }
      
      if (lastZeroDate != null) {
        debugPrint('Last zero balance date for account $accountName: $lastZeroDate');
        if (previousZeroDate != null) {
          debugPrint('Previous zero balance date for account $accountName: $previousZeroDate');
        }
        return (lastZeroDate: lastZeroDate, previousZeroDate: previousZeroDate);
      } else {
        debugPrint('No zero balance found in GL Entries for account: $accountName');
        return null;
      }
    } catch (e) {
      debugPrint('Could not query GL Entry for zero balance date: $e (this is optional)');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeJournalEntries(String employeeId) async {
    try {
      // First, try to get employee's account from Employee record
      // Common field names: 'account', 'payable_account', 'receivable_account', 'default_account', 'custom_advance_account__حساب_السلفة'
      String? employeeAccount;
      try {
        final empRes = await _dio.get('/api/resource/Employee/$employeeId', queryParameters: {
          'fields': jsonEncode([
            'account',
            'payable_account',
            'receivable_account',
            'default_account',
            'custom_advance_account__حساب_السلفة',
          ]),
        });
        final empData = empRes.data is Map ? empRes.data['data'] : null;
        if (empData is Map) {
          // Try common account field names (prioritize custom_advance_account__حساب_السلفة first)
          employeeAccount = empData['custom_advance_account__حساب_السلفة'] as String? ??
              empData['account'] as String? ??
              empData['payable_account'] as String? ??
              empData['receivable_account'] as String? ??
              empData['default_account'] as String?;
          debugPrint('Employee account fetched: $employeeAccount (from field: ${empData['custom_advance_account__حساب_السلفة'] != null ? 'custom_advance_account__حساب_السلفة' : (empData['account'] != null ? 'account' : 'other')})');
        }
      } catch (e) {
        debugPrint('Could not fetch employee account: $e');
      }

      // Try to find last two zero balance dates to optimize query
      ({DateTime lastZeroDate, DateTime? previousZeroDate})? zeroBalanceDates;
      if (employeeAccount != null && employeeAccount.isNotEmpty) {
        zeroBalanceDates = await _findLastTwoZeroBalanceDates(employeeAccount);
      }

      // Use zero balance dates if found, otherwise fall back to 3 years ago
      final DateTime dateFilterStart;
      final DateTime? dateFilterEnd;
      if (zeroBalanceDates != null && zeroBalanceDates.previousZeroDate != null) {
        // Fetch entries from day after previous zero balance (exclude the entry that made the previous zero balance)
        // No upper bound - include all entries after the last zero balance as well
        dateFilterStart = zeroBalanceDates.previousZeroDate!.add(const Duration(days: 1));
        dateFilterEnd = null; // No upper bound - fetch all entries after the start date
        debugPrint('Using optimized date filter from day after previous zero balance: ${dateFilterStart.toIso8601String().split('T')[0]} (including all entries after last zero balance: ${zeroBalanceDates.lastZeroDate.toIso8601String().split('T')[0]})');
      } else if (zeroBalanceDates != null) {
        // Only one zero balance found, use it as the filter (no upper bound)
        dateFilterStart = zeroBalanceDates.lastZeroDate;
        dateFilterEnd = null;
        debugPrint('Using optimized date filter from last zero balance: ${dateFilterStart.toIso8601String().split('T')[0]}');
      } else {
        // Fallback to last 3 years if we can't determine zero balance date
        final threeYearsAgo = DateTime.now().subtract(const Duration(days: 3 * 365));
        dateFilterStart = threeYearsAgo;
        dateFilterEnd = null;
        debugPrint('Using fallback date filter (last 3 years): ${dateFilterStart.toIso8601String().split('T')[0]}');
      }
      
      final dateFilterStr = dateFilterStart.toIso8601String().split('T')[0];
      final dateFilterEndStr = dateFilterEnd?.toIso8601String().split('T')[0];

      // Note: ERPNext list queries don't include child tables, so we can't filter by account in the accounts child table
      // We must fetch each Journal Entry individually to check the accounts child table
      // This is slower but necessary without a custom ERPNext API endpoint
      // Limit to recent entries only to improve performance
           // Note: This method is slower as it makes individual API calls per entry to check accounts child table
           // ERPNext doesn't allow filtering by child table fields, so we must fetch each entry individually
           // Limit to 30 entries max to improve performance (most recent first)
           // For better performance, create a custom ERPNext API method that filters server-side by account
           debugPrint('Using slower method: fetching Journal Entries individually to check accounts child table');
           
           // Extract account code for matching
           String? accountCode;
           if (employeeAccount != null && employeeAccount.isNotEmpty) {
             final accountParts = employeeAccount.split(' - ');
             accountCode = accountParts.isNotEmpty ? accountParts[0].trim() : employeeAccount;
           }
           
           // Fetch ALL Journal Entries from the date range using pagination
           // We need all entries, not just the most recent ones, to include entries between zero balance dates
           final allEntries = <Map<String, dynamic>>[];
           int start = 0;
           const pageLength = 200;
           
           while (true) {
             final res = await _dio.get(
               '/api/resource/Journal Entry',
               queryParameters: {
                 'fields': jsonEncode([
                   'name',
                   'posting_date',
                   'voucher_type',
                   'total_debit',
                   'total_credit',
                   'company',
                   'remark',
                 ]),
                 'filters': jsonEncode([
                   ['docstatus', '=', 1],
                   ['posting_date', '>=', dateFilterStr],
                   if (dateFilterEndStr != null) ['posting_date', '<=', dateFilterEndStr],
                 ]),
                 'order_by': 'posting_date desc',
                 'limit_start': start,
                 'limit_page_length': pageLength,
               },
             );
             
             final entries = (res.data is Map) ? (res.data['data'] as List?) : null;
             if (entries == null || entries.isEmpty) break;
             
             allEntries.addAll(entries.cast<Map<String, dynamic>>());
             
             // If we got fewer entries than the page length, we've reached the end
             if (entries.length < pageLength) break;
             
             start += pageLength;
           }
           
           if (allEntries.isEmpty) return [];
           
           debugPrint('Fetched ${allEntries.length} Journal Entries to check');
           
           if (allEntries.isEmpty) return [];

           // Now filter entries that have this employee in their accounts
           // Process in parallel batches for much better performance
           final employeeEntries = <Map<String, dynamic>>[];
           
           // Process entries in parallel batches of 10 for better performance
           const batchSize = 10;
           for (int i = 0; i < allEntries.length; i += batchSize) {
             final batch = allEntries.skip(i).take(batchSize).toList();
             
             // Fetch all entries in this batch in parallel
             final batchResults = await Future.wait(
               batch.map((entry) async {
                 final entryName = entry['name'] as String?;
                 if (entryName == null) return null;

                 try {
                   // Get the full journal entry to check accounts with shorter timeout
                   final entryDetail = await _dio.get(
                     '/api/resource/Journal Entry/$entryName',
                     queryParameters: {
                       'fields': jsonEncode(['accounts']),
                     },
                   ).timeout(const Duration(seconds: 3));

                   final entryData = entryDetail.data is Map ? entryDetail.data['data'] : null;
                   if (entryData is! Map) return null;
                   
                   final accounts = entryData['accounts'] as List?;
                   if (accounts == null) return null;

                   // Check if any account entry has this employee as party or account
                   double debitTotal = 0;
                   double creditTotal = 0;

                   for (final acc in accounts) {
                     if (acc is! Map) continue;
                     
                     final partyType = acc['party_type'] as String?;
                     final party = acc['party'] as String?;
                     final accountName = acc['account'] as String?;
                     final debit = (acc['debit'] as num?)?.toDouble() ?? 0.0;
                     final credit = (acc['credit'] as num?)?.toDouble() ?? 0.0;

                     // Check both by employee ID (party) and by account if available
                     bool matchesEmployee = false;
                     if (partyType == 'Employee' && party == employeeId) {
                       matchesEmployee = true;
                     } else if (accountCode != null && accountName != null) {
                       // Check if account matches
                       if (accountName == employeeAccount || 
                           accountName == accountCode ||
                           accountName.startsWith('$accountCode ') ||
                           accountName.contains(accountCode)) {
                         matchesEmployee = true;
                       }
                     }
                     
                     if (matchesEmployee) {
                       debitTotal += debit;
                       creditTotal += credit;
                     }
                   }
                   
                   // Only return entry if there's at least one debit or credit
                   if (debitTotal > 0 || creditTotal > 0) {
                     final isPayment = debitTotal > 0;
                     final totalAmount = debitTotal - creditTotal;
                     
                     return {
                       'name': entryName,
                       'posting_date': entry['posting_date'],
                       'total_claimed_amount': totalAmount.abs(),
                       'total_sanctioned_amount': totalAmount.abs(),
                       'debit_amount': debitTotal,
                       'credit_amount': creditTotal,
                       'status': 'Draft',
                       'company': entry['company'],
                       'remark': entry['remark'] ?? '',
                       'voucher_type': entry['voucher_type'] ?? 'Journal Entry',
                       'source_type': 'Journal Entry',
                       'is_payment': isPayment,
                     };
                   }
                   return null;
                 } catch (e) {
                   // Skip entries that fail or timeout
                   return null;
                 }
               }),
               eagerError: false, // Don't fail entire batch if one fails
             );
             
             // Add successful results to the list
             for (final result in batchResults) {
               if (result != null) {
                 employeeEntries.add(result);
               }
             }
           }

      return employeeEntries;
    } on DioException catch (e) {
      debugPrint('Error fetching journal entries: ${e.response?.data}');
      // Return empty list if there's a permission error
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching journal entries: $e');
      return [];
    }
  }

  /// Process Journal Entry Account data (works for both account-based and party-based queries)
  Future<List<Map<String, dynamic>>> _processJournalEntryAccounts(List accountData, String dateFilter) async {
    // Group by parent (Journal Entry) and calculate totals
    final entryMap = <String, Map<String, dynamic>>{};
    
    for (final acc in accountData) {
      if (acc is! Map) continue;
      final parent = acc['parent'] as String?;
      if (parent == null) continue;

      final debit = (acc['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (acc['credit'] as num?)?.toDouble() ?? 0.0;
      double amount = 0;
      if (debit > 0) {
        amount = debit; // Payment to employee
      } else if (credit > 0) {
        amount = -credit; // Expense from employee
      }

      if (entryMap.containsKey(parent)) {
        final existing = entryMap[parent]!;
        final currentAmount = (existing['total_claimed_amount'] as num?)?.toDouble() ?? 0.0;
        final existingDebit = (existing['debit_amount'] as num?)?.toDouble() ?? 0.0;
        final existingCredit = (existing['credit_amount'] as num?)?.toDouble() ?? 0.0;
        
        existing['total_claimed_amount'] = (currentAmount + amount).abs();
        existing['is_payment'] = (currentAmount + amount) > 0;
        existing['debit_amount'] = existingDebit + (debit > 0 ? debit : 0);
        existing['credit_amount'] = existingCredit + (credit > 0 ? credit : 0);
      } else {
        entryMap[parent] = {
          'name': parent,
          'total_claimed_amount': amount.abs(),
          'is_payment': amount > 0,
          'debit_amount': debit > 0 ? debit : 0,
          'credit_amount': credit > 0 ? credit : 0,
        };
      }
    }

    // Now fetch basic info for these journal entries
    // Query all matching entries at once (ERPNext supports 'in' filter)
    final entryNames = entryMap.keys.toList();
    if (entryNames.isEmpty) return [];

    try {
      final batchRes = await _dio.get(
        '/api/resource/Journal Entry',
        queryParameters: {
          'fields': jsonEncode([
            'name',
            'posting_date',
            'voucher_type',
            'company',
            'remark',
          ]),
          'filters': jsonEncode([
            ['name', 'in', entryNames],
            ['posting_date', '>=', dateFilter],
            ['docstatus', '=', 1],
          ]),
          'limit_page_length': 1000,
        },
      );

      final batchData = (batchRes.data is Map) ? (batchRes.data['data'] as List?) : null;
      if (batchData != null) {
        final employeeEntries = <Map<String, dynamic>>[];
        
        for (final entry in batchData) {
          if (entry is! Map) continue;
          final entryName = entry['name'] as String?;
          if (entryName == null || !entryMap.containsKey(entryName)) continue;

          // Filter by date after fetching (since Journal Entry Account doesn't have posting_date)
          final postingDateStr = entry['posting_date'] as String?;
          if (postingDateStr != null && postingDateStr.compareTo(dateFilter) < 0) {
            continue; // Skip entries older than date filter
          }

          final entryInfo = entryMap[entryName]!;
          final debitAmt = (entryInfo['debit_amount'] as num?)?.toDouble() ?? 0.0;
          final creditAmt = (entryInfo['credit_amount'] as num?)?.toDouble() ?? 0.0;
          
          employeeEntries.add({
            ...entryInfo,
            'posting_date': entry['posting_date'],
            'total_sanctioned_amount': entryInfo['total_claimed_amount'],
            'total_claimed_amount': entryInfo['total_claimed_amount'],
            'debit_amount': debitAmt,
            'credit_amount': creditAmt,
            'status': 'Draft', // Journal entries are not automatically "Paid" - need Payment Entry to mark as paid
            'company': entry['company'],
            'remark': entry['remark'] ?? '',
            'voucher_type': entry['voucher_type'] ?? 'Journal Entry',
            'source_type': 'Journal Entry',
          });
        }

        // Sort by date descending
        employeeEntries.sort((a, b) {
          final dateA = a['posting_date'] as String? ?? '';
          final dateB = b['posting_date'] as String? ?? '';
          return dateB.compareTo(dateA);
        });

        return employeeEntries;
      }
    } catch (e) {
      debugPrint('Batch fetch failed: $e');
    }
    
    return [];
  }

  /// Get all employee expenses (only expenses, not payments)
  /// Includes Expense Claims and Journal Entry expenses (credit to employee)
  Future<List<Map<String, dynamic>>> getAllEmployeeExpenses(String employeeId) async {
    try {
      // Fetch expense claims
      final expenseClaims = await getEmployeeExpenses(employeeId);
      
      // Fetch journal entries but filter to only include expenses (not payments)
      final journalEntries = await getEmployeeJournalEntries(employeeId);
      
      // Filter journal entries to only include expenses (is_payment = false)
      final expenseJournalEntries = journalEntries.where((entry) {
        final isPayment = entry['is_payment'] as bool? ?? false;
        return !isPayment; // Only include expenses, exclude payments
      }).toList();

      // Add source type to expense claims
      // Expense claims are always expenses (RED), not payments
      final claimsWithSource = expenseClaims.map((claim) {
        return {
          ...claim,
          'source_type': 'Expense Claim',
          'is_payment': false, // Expense claims are expenses, not payments
        };
      }).toList();

      // Combine and sort by posting date (most recent first)
      final allExpenses = [...claimsWithSource, ...expenseJournalEntries];
      allExpenses.sort((a, b) {
        final dateA = a['posting_date'] as String? ?? '';
        final dateB = b['posting_date'] as String? ?? '';
        return dateB.compareTo(dateA); // Descending order
      });

      return allExpenses;
    } catch (e) {
      debugPrint('Error fetching all employee expenses: $e');
      // Fallback to just expense claims
      return await getEmployeeExpenses(employeeId);
    }
  }
  
  /// Get Payment Entry records for an employee
  /// dateFilterStart: Only fetch entries from this date forward (for optimization)
  /// dateFilterEnd: Only fetch entries up to this date (for optimization)
  /// Returns a tuple: (paymentEntries, journalEntryReferences)
  /// journalEntryReferences is a map of Journal Entry name -> list of amounts that reference it
  Future<({List<Map<String, dynamic>> paymentEntries, Map<String, List<double>> journalEntryReferences})> getEmployeePaymentEntries(String employeeId, {String? dateFilterStart, String? dateFilterEnd}) async {
    try {
      final filters = <List<dynamic>>[
        ['party_type', '=', 'Employee'],
        ['party', '=', employeeId],
        ['docstatus', '=', 1], // Only submitted entries
      ];
      
      // Apply date filters if provided (for optimization - only fetch between zero balance dates)
      if (dateFilterStart != null && dateFilterStart.isNotEmpty) {
        filters.add(['posting_date', '>=', dateFilterStart]);
      }
      if (dateFilterEnd != null && dateFilterEnd.isNotEmpty) {
        filters.add(['posting_date', '<=', dateFilterEnd]);
      }
      
      final res = await _dio.get(
        '/api/resource/Payment Entry',
        queryParameters: {
          'fields': jsonEncode([
            'name',
            'posting_date',
            'party_type',
            'party',
            'paid_amount',
            'received_amount',
            'payment_type',
            'mode_of_payment',
            'reference_no',
            'reference_date',
            'remarks',
            'company',
            'docstatus',
          ]),
          'filters': jsonEncode(filters),
          'order_by': 'posting_date desc',
          'limit_page_length': 500,
        },
      );

      final data = (res.data is Map) ? (res.data['data'] as List?) : null;
      if (data == null) return (paymentEntries: <Map<String, dynamic>>[], journalEntryReferences: <String, List<double>>{});

      // Fetch references for each Payment Entry to check Journal Entry references
      // Create a map of Journal Entry names to Payment Entry amounts
      final journalEntryReferences = <String, List<double>>{};
      
      // Fetch references in parallel batches for performance
      const batchSize = 10;
      for (int i = 0; i < data.length; i += batchSize) {
        final batch = data.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((entry) async {
            final entryName = entry['name'] as String?;
            if (entryName == null) return;
            
            try {
              final entryDetail = await _dio.get(
                '/api/resource/Payment Entry/$entryName',
                queryParameters: {
                  'fields': jsonEncode(['references']),
                },
              ).timeout(const Duration(seconds: 2));
              
              final entryData = entryDetail.data is Map ? entryDetail.data['data'] : null;
              if (entryData is! Map) return;
              
              final references = entryData['references'] as List?;
              if (references == null) return;
              
              final paidAmt = (entry['paid_amount'] as num?)?.toDouble() ?? 0.0;
              final receivedAmt = (entry['received_amount'] as num?)?.toDouble() ?? 0.0;
              final paymentType = entry['payment_type'] as String? ?? '';
              final isIn = paymentType == 'Receive' || receivedAmt > 0;
              final amount = isIn ? receivedAmt : paidAmt;
              
              for (final ref in references) {
                if (ref is! Map) continue;
                final refDoctype = ref['reference_doctype'] as String?;
                final refName = ref['reference_name'] as String?;
                
                if (refDoctype == 'Journal Entry' && refName != null && refName.isNotEmpty) {
                  journalEntryReferences.putIfAbsent(refName, () => []).add(amount);
                }
              }
            } catch (e) {
              // Skip entries that fail to fetch references
              debugPrint('Could not fetch references for Payment Entry $entryName: $e');
            }
          }),
          eagerError: false,
        );
      }

      // Convert Payment Entry to payment format
      final paymentEntriesList = data.map((entry) {
        final paidAmt = (entry['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final receivedAmt = (entry['received_amount'] as num?)?.toDouble() ?? 0.0;
        final paymentType = entry['payment_type'] as String? ?? '';
        
        // Determine direction: "Pay" = employee paying company (OUT), "Receive" = company paying employee (IN)
        final isIn = paymentType == 'Receive' || receivedAmt > 0;
        final amount = isIn ? receivedAmt : paidAmt;
        
        return {
          'name': entry['name'],
          'posting_date': entry['posting_date'],
          'payment_direction': isIn ? 'in' : 'out',
          'total_claimed_amount': amount,
          'total_sanctioned_amount': amount,
          'voucher_type': 'Payment Entry',
          'source_type': 'Payment Entry',
          'status': 'Paid', // Payment Entries are always paid
          'company': entry['company'],
          'remark': entry['remarks'] ?? '',
          'mode_of_payment': entry['mode_of_payment'] ?? '',
          'reference_no': entry['reference_no'] ?? '',
        };
      }).toList();
      
      return (paymentEntries: paymentEntriesList, journalEntryReferences: journalEntryReferences);
    } catch (e) {
      debugPrint('Error fetching Payment Entry records: $e (this is optional)');
      return (paymentEntries: <Map<String, dynamic>>[], journalEntryReferences: <String, List<double>>{}); // Return empty if Payment Entry query fails (permissions, etc.)
    }
  }

  /// Get all employee payments (both In and Out)
  /// Includes both Journal Entry and Payment Entry records
  /// In = Debit to employee (company paying employee) - stored as separate entries
  /// Out = Credit to employee (employee paying company) - stored as separate entries
  Future<List<Map<String, dynamic>>> getAllEmployeePayments(String employeeId) async {
    try {
      // First check if employee has an account configured
      String? employeeAccount;
      try {
        final empRes = await _dio.get('/api/resource/Employee/$employeeId', queryParameters: {
          'fields': jsonEncode([
            'custom_advance_account__حساب_السلفة',
            'account',
            'payable_account',
            'receivable_account',
            'default_account',
          ]),
        });
        final empData = empRes.data is Map ? empRes.data['data'] : null;
        if (empData is Map) {
          employeeAccount = empData['custom_advance_account__حساب_السلفة'] as String? ??
              empData['account'] as String? ??
              empData['payable_account'] as String? ??
              empData['receivable_account'] as String? ??
              empData['default_account'] as String?;
        }
      } catch (e) {
        debugPrint('Could not fetch employee account: $e');
      }
      
      // If no account is found, throw a specific error
      if (employeeAccount == null || employeeAccount.isEmpty) {
        throw StateError('NO_EMPLOYEE_ACCOUNT');
      }
      
      // Fetch Journal Entries first (it already calculates the date filter)
      final journalEntries = await getEmployeeJournalEntries(employeeId);
      
      // Get the date filters to use for Payment Entries (same as Journal Entries)
      String? dateFilterStartStr;
      String? dateFilterEndStr;
      try {
        final empRes = await _dio.get('/api/resource/Employee/$employeeId', queryParameters: {
          'fields': jsonEncode([
            'custom_advance_account__حساب_السلفة',
            'account',
            'payable_account',
            'receivable_account',
            'default_account',
          ]),
        });
        final empData = empRes.data is Map ? empRes.data['data'] : null;
        if (empData is Map) {
          final employeeAccount = empData['custom_advance_account__حساب_السلفة'] as String? ??
              empData['account'] as String? ??
              empData['payable_account'] as String? ??
              empData['receivable_account'] as String? ??
              empData['default_account'] as String?;
          
          if (employeeAccount != null && employeeAccount.isNotEmpty) {
            final zeroBalanceDates = await _findLastTwoZeroBalanceDates(employeeAccount);
            if (zeroBalanceDates != null && zeroBalanceDates.previousZeroDate != null) {
              // Use day after previous zero balance to exclude the entry that made the previous zero balance
              // No upper bound - include all entries after the last zero balance as well
              final dateFilterStart = zeroBalanceDates.previousZeroDate!.add(const Duration(days: 1));
              dateFilterStartStr = dateFilterStart.toIso8601String().split('T')[0];
              dateFilterEndStr = null; // No upper bound - fetch all entries after the start date
            } else if (zeroBalanceDates != null) {
              dateFilterStartStr = zeroBalanceDates.lastZeroDate.toIso8601String().split('T')[0];
            }
          }
        }
      } catch (e) {
        debugPrint('Could not determine date filter for Payment Entry (will fetch all): $e');
      }
      
      // Fetch Payment Entries with the same date filter range
      final paymentResult = await getEmployeePaymentEntries(employeeId, dateFilterStart: dateFilterStartStr, dateFilterEnd: dateFilterEndStr);
      final paymentEntriesFromPE = paymentResult.paymentEntries;
      final journalEntryReferences = paymentResult.journalEntryReferences;
      
      // Convert journal entries to payment entries
      // Net amount = debit - credit (positive = IN, negative = OUT)
      final paymentEntriesFromJE = <Map<String, dynamic>>[];
      
      for (final entry in journalEntries) {
        final debitAmt = (entry['debit_amount'] as num?)?.toDouble() ?? 0.0;
        final creditAmt = (entry['credit_amount'] as num?)?.toDouble() ?? 0.0;
        final netAmount = debitAmt - creditAmt;
        final journalEntryName = entry['name'] as String? ?? '';
        
        // Only create entry if there's a net amount (either debit or credit)
        if (netAmount != 0) {
          final absAmount = netAmount.abs();
          
          // Check if this Journal Entry is referenced by a Payment Entry
          // Status is "Paid" if there's a Payment Entry that references this Journal Entry and amounts match
          String status = 'Draft';
          if (journalEntryName.isNotEmpty && journalEntryReferences.containsKey(journalEntryName)) {
            final referencedAmounts = journalEntryReferences[journalEntryName]!;
            // Check if any referenced amount matches (within 0.01 for rounding)
            for (final refAmount in referencedAmounts) {
              if ((refAmount - absAmount).abs() < 0.01) {
                status = 'Paid';
                break;
              }
            }
          }
          
          paymentEntriesFromJE.add({
            ...entry,
            'payment_direction': netAmount > 0 ? 'in' : 'out',
            'total_claimed_amount': absAmount,
            'total_sanctioned_amount': absAmount,
            'status': status,
          });
        }
      }

      // Combine both sources
      final allPayments = [...paymentEntriesFromJE, ...paymentEntriesFromPE];

      // Sort by posting date (most recent first)
      allPayments.sort((a, b) {
        final dateA = a['posting_date'] as String? ?? '';
        final dateB = b['posting_date'] as String? ?? '';
        return dateB.compareTo(dateA); // Descending order
      });

      debugPrint('Fetched ${paymentEntriesFromJE.length} payments from Journal Entries and ${paymentEntriesFromPE.length} payments from Payment Entry');
      return allPayments;
    } catch (e) {
      // Re-throw StateError for NO_EMPLOYEE_ACCOUNT so it can be handled in the UI
      if (e is StateError && e.toString().contains('NO_EMPLOYEE_ACCOUNT')) {
        rethrow;
      }
      debugPrint('Error fetching employee payments: $e');
      return [];
    }
  }

  /// Create a new expense claim
  Future<Map<String, dynamic>> createExpenseClaim({
    required String employeeId,
    required List<Map<String, dynamic>> expenses,
    String? title,
    DateTime? postingDate,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'expenses': expenses,
      if (title != null) 'title': title,
      if (postingDate != null) 'posting_date': postingDate.toIso8601String().split('T')[0],
    };

    return create(payload);
  }

  /// Submit an expense claim
  Future<Map<String, dynamic>> submitExpenseClaim(String name) async {
    return submit(name);
  }

  /// Get expense claim details with expense items
  Future<Map<String, dynamic>> getExpenseDetails(String name) async {
    return get(name);
  }
}

/// Expense Claim Type Repository
class ExpenseTypeRepository extends ERPNextRepository {
  ExpenseTypeRepository(super.client);

  @override
  String get doctype => 'Expense Claim Type';

  /// Get all active expense types
  Future<List<Map<String, dynamic>>> getActiveExpenseTypes() async {
    return list(
      fields: [
        'name',
        'expense_type',
        'description',
      ],
      filters: [
        ['disabled', '=', 0],
      ],
      orderBy: 'expense_type asc',
    );
  }
}


