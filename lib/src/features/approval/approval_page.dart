import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'approval_repository.dart';

final approvalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  
  final approvalRepo = TodoRepository(client);
  return approvalRepo.getPendingApprovals();
});

class ApprovalPage extends ConsumerWidget {
  const ApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final approvals = ref.watch(approvalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.approvals),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(approvalsProvider.future),
        child: approvals.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fact_check_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No pending approvals', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _ApprovalCard(approval: items[index], ref: ref),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading approvals', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(approvalsProvider),
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

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({required this.approval, required this.ref});

  final Map<String, dynamic> approval;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = approval['description'] as String? ?? 'No description';
    final referenceType = approval['reference_type'] as String?;
    final referenceName = approval['reference_name'] as String?;
    final assignedDate = approval['assigned_date'] as String?;
    final priority = approval['priority'] as String? ?? 'Medium';

    Color priorityColor;
    switch (priority) {
      case 'High':
        priorityColor = Colors.red;
        break;
      case 'Medium':
        priorityColor = Colors.orange;
        break;
      case 'Low':
        priorityColor = Colors.blue;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.1),
          child: Icon(Icons.fact_check_rounded, color: priorityColor),
        ),
        title: Text(
          referenceType ?? 'Approval',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            if (referenceName != null) Text('Reference: $referenceName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (assignedDate != null) Text('Assigned: ${_formatDate(assignedDate)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: Chip(
          label: Text(priority),
          backgroundColor: priorityColor.withOpacity(0.1),
          labelStyle: TextStyle(color: priorityColor, fontSize: 12),
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

