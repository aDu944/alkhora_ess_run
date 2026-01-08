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
  /// Journal Entries that have the employee as a party in the accounts
  /// Optimized: Fetches only recent entries and limits number of API calls
  Future<List<Map<String, dynamic>>> getEmployeeJournalEntries(String employeeId) async {
    try {
      // Limit to last 6 months and only 50 most recent entries to improve performance
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final dateFilter = sixMonthsAgo.toIso8601String().split('T')[0];

      // Try to query Journal Entry Account directly first (if accessible)
      // This would be much faster but may not be permitted by role permissions
      try {
        final accountRes = await _dio.get(
          '/api/resource/Journal Entry Account',
          queryParameters: {
            'fields': jsonEncode([
              'parent',
              'party_type',
              'party',
              'debit',
              'credit',
            ]),
            'filters': jsonEncode([
              ['party_type', '=', 'Employee'],
              ['party', '=', employeeId],
              ['docstatus', '=', 1],
            ]),
            'limit_page_length': 100,
          },
        );

        final accountData = (accountRes.data is Map) ? (accountRes.data['data'] as List?) : null;
        if (accountData != null && accountData.isNotEmpty) {
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
                'limit_page_length': 100,
              },
            );

            final batchData = (batchRes.data is Map) ? (batchRes.data['data'] as List?) : null;
            if (batchData != null) {
              final employeeEntries = <Map<String, dynamic>>[];
              
              for (final entry in batchData) {
                if (entry is! Map) continue;
                final entryName = entry['name'] as String?;
                if (entryName == null || !entryMap.containsKey(entryName)) continue;

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
                  'status': 'Paid',
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
            debugPrint('Batch fetch failed, using individual queries: $e');
            // Fall through to individual query method if batch fails
          }
        }
      } catch (e) {
        debugPrint('Direct Journal Entry Account query failed, falling back to slower method: $e');
        // Fall through to slower method below
      }

      // Fallback: Slower method (only fetch last 30 entries to reduce load)
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
            ['posting_date', '>=', dateFilter],
          ]),
          'order_by': 'posting_date desc',
          'limit_page_length': 30, // Reduced from 200 to improve performance
        },
      );

      final allEntries = (res.data is Map) ? (res.data['data'] as List?) : null;
      if (allEntries == null) return [];

      // Now filter entries that have this employee in their accounts
      final employeeEntries = <Map<String, dynamic>>[];
      
      for (final entry in allEntries) {
        final entryName = entry['name'] as String?;
        if (entryName == null) continue;

        try {
          // Get the full journal entry to check accounts
          final entryDetail = await _dio.get(
            '/api/resource/Journal Entry/$entryName',
            queryParameters: {
              'fields': jsonEncode(['accounts']),
            },
          );

          final entryData = entryDetail.data is Map ? entryDetail.data['data'] : null;
          if (entryData is Map) {
            final accounts = entryData['accounts'] as List?;
            if (accounts != null) {
              // Check if any account entry has this employee as party
              bool hasEmployee = false;
              double totalAmount = 0;

              for (final acc in accounts) {
                if (acc is Map) {
                  final partyType = acc['party_type'] as String?;
                  final party = acc['party'] as String?;
                  final debit = (acc['debit'] as num?)?.toDouble() ?? 0.0;
                  final credit = (acc['credit'] as num?)?.toDouble() ?? 0.0;

                  if (partyType == 'Employee' && party == employeeId) {
                    hasEmployee = true;
                    // Track debit and credit separately
                    if (debit > 0) {
                      totalAmount += debit;
                    } else if (credit > 0) {
                      totalAmount -= credit;
                    }
                  }
                }
              }

              if (hasEmployee) {
                // Calculate debit and credit totals separately
                double debitTotal = 0;
                double creditTotal = 0;
                for (final acc in accounts) {
                  if (acc is Map) {
                    final partyType = acc['party_type'] as String?;
                    final party = acc['party'] as String?;
                    if (partyType == 'Employee' && party == employeeId) {
                      final debit = (acc['debit'] as num?)?.toDouble() ?? 0.0;
                      final credit = (acc['credit'] as num?)?.toDouble() ?? 0.0;
                      debitTotal += debit;
                      creditTotal += credit;
                    }
                  }
                }
                
                // Only add entry if there's at least one debit or credit
                if (debitTotal > 0 || creditTotal > 0) {
                  final isPayment = debitTotal > 0;
                  final totalAmount = debitTotal - creditTotal;
                  
                  employeeEntries.add({
                    'name': entryName,
                    'posting_date': entry['posting_date'],
                    'total_claimed_amount': totalAmount.abs(), // Store absolute value for backward compatibility
                    'total_sanctioned_amount': totalAmount.abs(),
                    'debit_amount': debitTotal,
                    'credit_amount': creditTotal,
                    'status': 'Paid', // Journal entries are already posted/paid
                    'company': entry['company'],
                    'remark': entry['remark'] ?? '',
                    'voucher_type': entry['voucher_type'] ?? 'Journal Entry',
                    'source_type': 'Journal Entry', // Flag to distinguish from Expense Claim
                    'is_payment': isPayment, // true = payment to employee (IN), false = expense/out (OUT)
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching journal entry details for $entryName: $e');
          // Continue with next entry
          continue;
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
  
  /// Get all employee payments (both In and Out)
  /// In = Debit to employee (company paying employee) - stored as separate entries
  /// Out = Credit to employee (employee paying company) - stored as separate entries
  Future<List<Map<String, dynamic>>> getAllEmployeePayments(String employeeId) async {
    try {
      // Fetch all journal entries (both debit and credit)
      final journalEntries = await getEmployeeJournalEntries(employeeId);
      
      // Separate payments into IN (debit) and OUT (credit)
      final paymentEntries = <Map<String, dynamic>>[];
      
      for (final entry in journalEntries) {
        final debitAmt = (entry['debit_amount'] as num?)?.toDouble() ?? 0.0;
        final creditAmt = (entry['credit_amount'] as num?)?.toDouble() ?? 0.0;
        
        // Add payment IN entry (debit)
        if (debitAmt > 0) {
          paymentEntries.add({
            ...entry,
            'payment_direction': 'in',
            'total_claimed_amount': debitAmt,
            'total_sanctioned_amount': debitAmt,
          });
        }
        
        // Add payment OUT entry (credit)
        // Note: We include all credits as potential payments OUT
        // In a real system, you might want to exclude expense-related credits
        if (creditAmt > 0) {
          paymentEntries.add({
            ...entry,
            'payment_direction': 'out',
            'total_claimed_amount': creditAmt,
            'total_sanctioned_amount': creditAmt,
            'name': '${entry['name']}_out', // Unique name for OUT entry
          });
        }
      }

      // Sort by posting date (most recent first)
      paymentEntries.sort((a, b) {
        final dateA = a['posting_date'] as String? ?? '';
        final dateB = b['posting_date'] as String? ?? '';
        return dateB.compareTo(dateA); // Descending order
      });

      return paymentEntries;
    } catch (e) {
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


