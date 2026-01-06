import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'leave_repository.dart';

final leaveApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final leaveRepo = LeaveRepository(client);
  return leaveRepo.getEmployeeLeaves(employeeId);
});

final leaveBalancesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final leaveAllocRepo = LeaveAllocationRepository(client);
  return leaveAllocRepo.getLeaveBalances(employeeId);
});

class LeavePage extends ConsumerWidget {
  const LeavePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final leaves = ref.watch(leaveApplicationsProvider);
    final balances = ref.watch(leaveBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.leave),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showApplyLeaveDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(leaveApplicationsProvider.future),
          ref.refresh(leaveBalancesProvider.future),
        ]),
        child: CustomScrollView(
          slivers: [
            // Leave Balances
            SliverToBoxAdapter(
              child: balances.when(
                data: (bals) => _LeaveBalancesCard(balances: bals),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Leave Applications
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: leaves.when(
                data: (items) => items.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.beach_access_rounded, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No leave applications yet', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _LeaveItemCard(leave: items[index]),
                          childCount: items.length,
                        ),
                      ),
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading leaves', style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 8),
                        Text(err.toString(), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplyLeaveDialog(BuildContext context, WidgetRef ref) {
    // Placeholder for apply leave dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply for Leave'),
        content: const Text('Leave application form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _LeaveBalancesCard extends StatelessWidget {
  const _LeaveBalancesCard({required this.balances});

  final List<Map<String, dynamic>> balances;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Balances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...balances.take(5).map((bal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bal['leave_type'] as String? ?? '—',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        '${bal['unused_leaves'] ?? 0} days',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _LeaveItemCard extends StatelessWidget {
  const _LeaveItemCard({required this.leave});

  final Map<String, dynamic> leave;

  @override
  Widget build(BuildContext context) {
    final fromDate = leave['from_date'] as String?;
    final toDate = leave['to_date'] as String?;
    final status = leave['status'] as String? ?? 'Open';
    final leaveType = leave['leave_type'] as String? ?? '—';
    final days = leave['total_leave_days'] as num? ?? 0;

    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.beach_access_rounded, color: statusColor),
        ),
        title: Text(leaveType),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromDate != null && toDate != null)
              Text('${_formatDate(fromDate)} - ${_formatDate(toDate)}'),
            Text('$days day${days != 1 ? 's' : ''}'),
          ],
        ),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withOpacity(0.1),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
        ),
        isThreeLine: true,
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

