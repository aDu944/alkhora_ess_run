import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'payslip_repository.dart';

final payslipsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final payslipRepo = PayslipRepository(client);
  return payslipRepo.getEmployeePayslips(employeeId);
});

class PayslipPage extends ConsumerWidget {
  const PayslipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final payslips = ref.watch(payslipsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.payslips)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(payslipsProvider.future),
        child: payslips.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No payslips available', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _PayslipCard(payslip: items[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading payslips', style: TextStyle(color: Colors.red[700])),
                TextButton(
                  onPressed: () => ref.refresh(payslipsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.payslip});

  final Map<String, dynamic> payslip;

  @override
  Widget build(BuildContext context) {
    final postingDate = payslip['posting_date'] as String?;
    final startDate = payslip['start_date'] as String?;
    final endDate = payslip['end_date'] as String?;
    final netPay = payslip['net_pay'] as num?;
    final status = payslip['status'] as String? ?? 'Draft';
    final name = payslip['name'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.receipt_long_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(_formatDateRange(startDate, endDate)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (postingDate != null) Text('Posted: ${_formatDate(postingDate)}'),
            Text('Status: $status'),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (netPay != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    NumberFormat.currency(symbol: '').format(netPay),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              TextButton(
                onPressed: () => _downloadPayslip(context, name),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null && end == null) return 'Payslip';
    if (start == null) return _formatDate(end);
    if (end == null) return _formatDate(start);
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  void _downloadPayslip(BuildContext context, String name) {
    // TODO: Implement payslip download/view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payslip $name details will be shown here')),
    );
  }
}

