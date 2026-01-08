import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import '../expense/expense_repository.dart';

final paymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final expenseRepo = ExpenseRepository(client);
  // Fetch only payments (in and out)
  return expenseRepo.getAllEmployeePayments(employeeId);
});

// Filter state provider for payments
class PaymentFilters {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? paymentType; // 'All', 'In', 'Out'
  final double? minAmount;
  final double? maxAmount;

  PaymentFilters({
    this.fromDate,
    this.toDate,
    this.paymentType,
    this.minAmount,
    this.maxAmount,
  });

  PaymentFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? paymentType,
    double? minAmount,
    double? maxAmount,
  }) {
    return PaymentFilters(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      paymentType: paymentType ?? this.paymentType,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }

  bool hasFilters() {
    return fromDate != null ||
        toDate != null ||
        (paymentType != null && paymentType != 'All') ||
        minAmount != null ||
        maxAmount != null;
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> payments) {
    return payments.where((payment) {
      // Date filter
      if (fromDate != null || toDate != null) {
        final postingDateStr = payment['posting_date'] as String?;
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

      // Payment type filter
      if (paymentType != null && paymentType != 'All') {
        final direction = payment['payment_direction'] as String?;
        if (paymentType == 'In' && direction != 'in') return false;
        if (paymentType == 'Out' && direction != 'out') return false;
      }

      // Amount filter
      final amount = (payment['total_claimed_amount'] as num?)?.toDouble() ?? 0.0;
      if (minAmount != null && amount < minAmount!) return false;
      if (maxAmount != null && amount > maxAmount!) return false;

      return true;
    }).toList();
  }
}

final paymentFiltersProvider = StateProvider<PaymentFilters>((ref) => PaymentFilters());

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final payments = ref.watch(paymentsProvider);
    final filters = ref.watch(paymentFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.payments),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(paymentsProvider.future),
        child: payments.when(
          data: (items) {
            final filteredItems = filters.applyFilters(items);
            
            // Calculate summary totals
            double totalIn = 0; // Payments received (In)
            double totalOut = 0; // Payments made (Out)
            
            for (final item in filteredItems) {
              final amount = (item['total_claimed_amount'] as num?)?.toDouble() ?? 0.0;
              final direction = item['payment_direction'] as String?;
              
              if (direction == 'in') {
                totalIn += amount; // Payment received
              } else if (direction == 'out') {
                totalOut += amount; // Payment made
              }
            }
            
            final netAmount = totalIn - totalOut;
            
            // Quick filter buttons
            final now = DateTime.now();
            final thisYearStart = DateTime(now.year, 1, 1);
            final lastYearStart = DateTime(now.year - 1, 1, 1);
            final lastYearEnd = DateTime(now.year - 1, 12, 31);
            
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
                        t.paymentsSummary,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryItem(
                              label: t.receivedIn,
                              amount: totalIn,
                              color: Colors.green[300]!,
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryItem(
                              label: t.paidOut,
                              amount: totalOut,
                              color: Colors.orange[300]!,
                              icon: Icons.arrow_upward_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white30, thickness: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.netAmount,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            netAmount >= 0 
                                ? '+${NumberFormat('#,##0.00').format(netAmount)}'
                                : NumberFormat('#,##0.00').format(netAmount),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: netAmount >= 0 ? Colors.green[100] : Colors.red[100],
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
                                label: t.thisYear,
                                isActive: filters.fromDate?.year == thisYearStart.year &&
                                         filters.fromDate?.month == 1 &&
                                         filters.fromDate?.day == 1 &&
                                         filters.toDate == null,
                                onTap: () {
                                  ref.read(paymentFiltersProvider.notifier).state = PaymentFilters(
                                    fromDate: thisYearStart,
                                    toDate: null,
                                    paymentType: filters.paymentType,
                                    minAmount: filters.minAmount,
                                    maxAmount: filters.maxAmount,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterButton(
                                label: t.lastYear,
                                isActive: filters.fromDate?.year == lastYearStart.year &&
                                         filters.fromDate?.month == 1 &&
                                         filters.fromDate?.day == 1 &&
                                         filters.toDate?.year == lastYearEnd.year &&
                                         filters.toDate?.month == 12 &&
                                         filters.toDate?.day == 31,
                                onTap: () {
                                  ref.read(paymentFiltersProvider.notifier).state = PaymentFilters(
                                    fromDate: lastYearStart,
                                    toDate: lastYearEnd,
                                    paymentType: filters.paymentType,
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
                              Icon(Icons.payment_rounded, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                filters.hasFilters() 
                                    ? t.noPaymentsMatchFilters 
                                    : t.noPaymentsYet,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (filters.hasFilters()) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => ref.read(paymentFiltersProvider.notifier).state = PaymentFilters(),
                                  child: Text(t.clearFilters),
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
                                                onDeleted: () => ref.read(paymentFiltersProvider.notifier).state =
                                                    filters.copyWith(fromDate: null),
                                              ),
                                            if (filters.toDate != null)
                                              _FilterChip(
                                                label: 'To: ${DateFormat('MMM d, yyyy').format(filters.toDate!)}',
                                                onDeleted: () => ref.read(paymentFiltersProvider.notifier).state =
                                                    filters.copyWith(toDate: null),
                                              ),
                                            if (filters.paymentType != null && filters.paymentType != 'All')
                                              _FilterChip(
                                                label: filters.paymentType!,
                                                onDeleted: () => ref.read(paymentFiltersProvider.notifier).state =
                                                    filters.copyWith(paymentType: 'All'),
                                              ),
                                            if (filters.minAmount != null || filters.maxAmount != null)
                                              _FilterChip(
                                                label: filters.minAmount != null && filters.maxAmount != null
                                                    ? '${NumberFormat('#,##0').format(filters.minAmount!)} - ${NumberFormat('#,##0').format(filters.maxAmount!)}'
                                                    : filters.minAmount != null
                                                        ? 'Min: ${NumberFormat('#,##0').format(filters.minAmount!)}'
                                                        : 'Max: ${NumberFormat('#,##0').format(filters.maxAmount!)}',
                                                onDeleted: () => ref.read(paymentFiltersProvider.notifier).state =
                                                    filters.copyWith(minAmount: null, maxAmount: null),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref.read(paymentFiltersProvider.notifier).state = PaymentFilters(),
                                      child: Text(t.clearAll),
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
                                    '${filteredItems.length} ${t.ofPayments} ${items.length}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Payments list
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredItems.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, index) => _PaymentCard(payment: filteredItems[index]),
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
                Text('Error loading payments', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(paymentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFiltersDialog(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final filters = ref.read(paymentFiltersProvider);
    DateTime? fromDate = filters.fromDate;
    DateTime? toDate = filters.toDate;
    String? paymentType = filters.paymentType ?? t.all;
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
          title: Text(t.filterPayments),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range
                Text(t.dateRange, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(fromDate != null 
                            ? DateFormat('MMM d, yyyy').format(fromDate!)
                            : t.fromDate),
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
                            : t.toDate),
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

                // Payment Type
                Text(t.paymentType, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(t.all)),
                    DropdownMenuItem(value: 'In', child: Text(t.receivedIn)),
                    DropdownMenuItem(value: 'Out', child: Text(t.paidOut)),
                  ],
                  onChanged: (value) => setDialogState(() => paymentType = value),
                ),
                const SizedBox(height: 16),

                // Amount Range
                Text(t.amountRange, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromAmountController,
                        decoration: InputDecoration(
                          labelText: t.min,
                          border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: t.max,
                          border: const OutlineInputBorder(),
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
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () {
                ref.read(paymentFiltersProvider.notifier).state = PaymentFilters();
                fromAmountController.dispose();
                toAmountController.dispose();
                Navigator.of(ctx).pop();
              },
              child: Text(t.clearAll),
            ),
            ElevatedButton(
              onPressed: () {
                final minAmount = fromAmountController.text.trim().isEmpty
                    ? null
                    : double.tryParse(fromAmountController.text.trim());
                final maxAmount = toAmountController.text.trim().isEmpty
                    ? null
                    : double.tryParse(toAmountController.text.trim());

                ref.read(paymentFiltersProvider.notifier).state = PaymentFilters(
                  fromDate: fromDate,
                  toDate: toDate,
                  paymentType: paymentType == 'All' ? null : paymentType,
                  minAmount: minAmount,
                  maxAmount: maxAmount,
                );
                fromAmountController.dispose();
                toAmountController.dispose();
                Navigator.of(ctx).pop();
              },
              child: Text(t.apply),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.payment});

  final Map<String, dynamic> payment;

  String _formatAmount(num amount) {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final postingDate = payment['posting_date'] as String?;
    final totalAmount = payment['total_claimed_amount'] as num? ?? 0;
    final status = payment['status'] as String? ?? 'Paid';
    final remark = payment['remark'] as String?;
    final voucherType = payment['voucher_type'] as String?;
    final direction = payment['payment_direction'] as String? ?? 'in';
    final isIn = direction == 'in';
    final documentId = payment['name'] as String?; // Document ID from ERPNext

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isIn ? Colors.green : Colors.orange).withOpacity(0.1),
          child: Icon(
            isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isIn ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          postingDate != null ? _formatDate(postingDate) : 'No date',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (documentId != null) ...[
              Text(
                '${t.documentId}: $documentId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text('${t.status}: $status'),
            if (voucherType != null && voucherType.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                voucherType,
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
          '${isIn ? '+' : '-'}${_formatAmount(totalAmount)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isIn ? Colors.green[700] : Colors.orange[700],
              ),
        ),
        isThreeLine: (voucherType != null && voucherType.isNotEmpty) || (remark != null && remark.isNotEmpty),
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

