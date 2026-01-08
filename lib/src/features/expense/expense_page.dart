import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'expense_repository.dart';

final expenseClaimsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final expenseRepo = ExpenseRepository(client);
  // Fetch both Expense Claims and Journal Entry expenses
  return expenseRepo.getAllEmployeeExpenses(employeeId);
});

// Filter state provider
class ExpenseFilters {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? sourceType; // 'All', 'Expense Claim', 'Journal Entry'
  final String? status; // 'All', 'Draft', 'Approved', 'Rejected', 'Paid'
  final double? minAmount;
  final double? maxAmount;

  ExpenseFilters({
    this.fromDate,
    this.toDate,
    this.sourceType,
    this.status,
    this.minAmount,
    this.maxAmount,
  });

  ExpenseFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? sourceType,
    String? status,
    double? minAmount,
    double? maxAmount,
  }) {
    return ExpenseFilters(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }

  bool hasFilters() {
    return fromDate != null ||
        toDate != null ||
        (sourceType != null && sourceType != 'All') ||
        (status != null && status != 'All') ||
        minAmount != null ||
        maxAmount != null;
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> expenses) {
    return expenses.where((expense) {
      // Date filter
      if (fromDate != null || toDate != null) {
        final postingDateStr = expense['posting_date'] as String?;
        if (postingDateStr != null) {
          try {
            final postingDate = DateTime.parse(postingDateStr);
            if (fromDate != null && postingDate.isBefore(fromDate!)) return false;
            if (toDate != null && postingDate.isAfter(toDate!.add(const Duration(days: 1)))) return false;
          } catch (_) {
            return false;
          }
        } else {
          return false;
        }
      }

      // Source type filter
      if (sourceType != null && sourceType != 'All') {
        final expenseSourceType = expense['source_type'] as String? ?? 'Expense Claim';
        if (expenseSourceType != sourceType) return false;
      }

      // Status filter
      if (status != null && status != 'All') {
        final expenseStatus = expense['status'] as String? ?? 'Draft';
        if (expenseStatus != status) return false;
      }

      // Amount filter
      final amount = (expense['total_claimed_amount'] as num?)?.toDouble() ?? 0.0;
      if (minAmount != null && amount < minAmount!) return false;
      if (maxAmount != null && amount > maxAmount!) return false;

      return true;
    }).toList();
  }
}

final expenseFiltersProvider = StateProvider<ExpenseFilters>((ref) => ExpenseFilters());

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final expenses = ref.watch(expenseClaimsProvider);
    final filters = ref.watch(expenseFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.expenses),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list_rounded),
                if (filters.hasFilters())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFiltersDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateExpenseDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(expenseClaimsProvider.future),
        child: expenses.when(
          data: (items) {
            final filteredItems = filters.applyFilters(items);
            
            // Quick filter buttons
            final now = DateTime.now();
            final thisYearStart = DateTime(now.year, 1, 1);
            final lastYearStart = DateTime(now.year - 1, 1, 1);
            final lastYearEnd = DateTime(now.year - 1, 12, 31);
            
            // Calculate summary totals (only expenses, not payments)
            double totalExpenses = 0; // Total expenses from employee
            
            for (final item in filteredItems) {
              final amount = (item['total_claimed_amount'] as num?)?.toDouble() ?? 0.0;
              totalExpenses += amount; // All items in expense page are expenses
            }
            
            return Column(
              children: [
                // Summary card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1C4CA5), Color(0xFF3B6FD8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Expenses',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            NumberFormat('#,##0.00').format(totalExpenses),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick filter buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[50],
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _QuickFilterButton(
                                label: 'This Year',
                                isActive: filters.fromDate?.year == thisYearStart.year &&
                                         filters.fromDate?.month == 1 &&
                                         filters.fromDate?.day == 1 &&
                                         filters.toDate == null,
                                onTap: () {
                                  ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(
                                    fromDate: thisYearStart,
                                    toDate: null,
                                    sourceType: filters.sourceType,
                                    status: filters.status,
                                    minAmount: filters.minAmount,
                                    maxAmount: filters.maxAmount,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterButton(
                                label: 'Last Year',
                                isActive: filters.fromDate?.year == lastYearStart.year &&
                                         filters.fromDate?.month == 1 &&
                                         filters.fromDate?.day == 1 &&
                                         filters.toDate?.year == lastYearEnd.year &&
                                         filters.toDate?.month == 12 &&
                                         filters.toDate?.day == 31,
                                onTap: () {
                                  ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(
                                    fromDate: lastYearStart,
                                    toDate: lastYearEnd,
                                    sourceType: filters.sourceType,
                                    status: filters.status,
                                    minAmount: filters.minAmount,
                                    maxAmount: filters.maxAmount,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.request_quote_rounded, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                filters.hasFilters() 
                                    ? 'No expenses match the filters' 
                                    : 'No expense claims yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (filters.hasFilters()) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(),
                                  child: const Text('Clear Filters'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Filter chips bar
                            if (filters.hasFilters())
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: Colors.grey[100],
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            if (filters.fromDate != null)
                                              _FilterChip(
                                                label: 'From: ${DateFormat('MMM d, yyyy').format(filters.fromDate!)}',
                                                onDeleted: () => ref.read(expenseFiltersProvider.notifier).state =
                                                    filters.copyWith(fromDate: null),
                                              ),
                                            if (filters.toDate != null)
                                              _FilterChip(
                                                label: 'To: ${DateFormat('MMM d, yyyy').format(filters.toDate!)}',
                                                onDeleted: () => ref.read(expenseFiltersProvider.notifier).state =
                                                    filters.copyWith(toDate: null),
                                              ),
                                            if (filters.sourceType != null && filters.sourceType != 'All')
                                              _FilterChip(
                                                label: filters.sourceType!,
                                                onDeleted: () => ref.read(expenseFiltersProvider.notifier).state =
                                                    filters.copyWith(sourceType: 'All'),
                                              ),
                                            if (filters.status != null && filters.status != 'All')
                                              _FilterChip(
                                                label: filters.status!,
                                                onDeleted: () => ref.read(expenseFiltersProvider.notifier).state =
                                                    filters.copyWith(status: 'All'),
                                              ),
                                            if (filters.minAmount != null || filters.maxAmount != null)
                                              _FilterChip(
                                                label: filters.minAmount != null && filters.maxAmount != null
                                                    ? '${NumberFormat('#,##0').format(filters.minAmount!)} - ${NumberFormat('#,##0').format(filters.maxAmount!)}'
                                                    : filters.minAmount != null
                                                        ? 'Min: ${NumberFormat('#,##0').format(filters.minAmount!)}'
                                                        : 'Max: ${NumberFormat('#,##0').format(filters.maxAmount!)}',
                                                onDeleted: () => ref.read(expenseFiltersProvider.notifier).state =
                                                    filters.copyWith(minAmount: null, maxAmount: null),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(),
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                ),
                              ),
                            // Results count
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${filteredItems.length} of ${items.length} expenses',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Expenses list
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredItems.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, index) => _ExpenseCard(expense: filteredItems[index]),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading expenses', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(expenseClaimsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateExpenseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Expense Claim'),
        content: const Text('Expense claim creation form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFiltersDialog(BuildContext context, WidgetRef ref) {
    final filters = ref.read(expenseFiltersProvider);
    DateTime? fromDate = filters.fromDate;
    DateTime? toDate = filters.toDate;
    String? sourceType = filters.sourceType ?? 'All';
    String? status = filters.status ?? 'All';
    final fromAmountController = TextEditingController(
      text: filters.minAmount?.toStringAsFixed(0) ?? '',
    );
    final toAmountController = TextEditingController(
      text: filters.maxAmount?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Filter Expenses'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(fromDate != null 
                            ? DateFormat('MMM d, yyyy').format(fromDate!)
                            : 'From Date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: fromDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => fromDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(toDate != null 
                            ? DateFormat('MMM d, yyyy').format(toDate!)
                            : 'To Date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: toDate ?? DateTime.now(),
                            firstDate: fromDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => toDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Source Type
                const Text('Source Type', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: sourceType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Expense Claim', child: Text('Expense Claim')),
                    DropdownMenuItem(value: 'Journal Entry', child: Text('Journal Entry')),
                  ],
                  onChanged: (value) => setDialogState(() => sourceType = value),
                ),
                const SizedBox(height: 16),

                // Status
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                  ],
                  onChanged: (value) => setDialogState(() => status = value),
                ),
                const SizedBox(height: 16),

                // Amount Range
                const Text('Amount Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                fromAmountController.dispose();
                toAmountController.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters();
                fromAmountController.dispose();
                toAmountController.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Clear All'),
            ),
            ElevatedButton(
              onPressed: () {
                final minAmount = fromAmountController.text.trim().isEmpty
                    ? null
                    : double.tryParse(fromAmountController.text.trim());
                final maxAmount = toAmountController.text.trim().isEmpty
                    ? null
                    : double.tryParse(toAmountController.text.trim());

                ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(
                  fromDate: fromDate,
                  toDate: toDate,
                  sourceType: sourceType == 'All' ? null : sourceType,
                  status: status == 'All' ? null : status,
                  minAmount: minAmount,
                  maxAmount: maxAmount,
                );
                fromAmountController.dispose();
                toAmountController.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Map<String, dynamic> expense;

  String _formatAmount(num amount) {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final postingDate = expense['posting_date'] as String?;
    final totalAmount = expense['total_claimed_amount'] as num? ?? 0;
    final status = expense['status'] as String? ?? 'Draft';
    final sourceType = expense['source_type'] as String? ?? 'Expense Claim';
    final remark = expense['remark'] as String?;
    final voucherType = expense['voucher_type'] as String?;
    final isPayment = expense['is_payment'] as bool? ?? false;

    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      case 'Paid':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    // Use different icon for Journal Entry
    final icon = sourceType == 'Journal Entry' 
        ? Icons.description_rounded 
        : Icons.request_quote_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(icon, color: statusColor),
        ),
        title: Text(
          postingDate != null ? _formatDate(postingDate) : 'No date',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status'),
            if (sourceType == 'Journal Entry') ...[
              const SizedBox(height: 4),
              Text(
                voucherType ?? 'Journal Entry',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (remark != null && remark.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                remark,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Text(
          isPayment ? '+${_formatAmount(totalAmount)}' : '-${_formatAmount(totalAmount)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPayment ? Colors.green[700] : Colors.red[700],
              ),
        ),
        isThreeLine: sourceType == 'Journal Entry' || (remark != null && remark.isNotEmpty),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _QuickFilterButton extends StatelessWidget {
  const _QuickFilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF1C4CA5) : Colors.transparent,
        foregroundColor: isActive ? Colors.white : const Color(0xFF1C4CA5),
        side: BorderSide(
          color: isActive ? const Color(0xFF1C4CA5) : Colors.grey[300]!,
          width: isActive ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

