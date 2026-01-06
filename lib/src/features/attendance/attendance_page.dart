import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'attendance_repository.dart';

final attendanceRecordsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final attRepo = AttendanceRecordsRepository(client);
  return attRepo.getCurrentMonthAttendance(employeeId);
});

class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final records = ref.watch(attendanceRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.attendance)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(attendanceRecordsProvider.future),
        child: records.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No attendance records', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _AttendanceCard(record: items[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading attendance', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(attendanceRecordsProvider),
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

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final date = record['attendance_date'] as String?;
    final status = record['status'] as String? ?? 'Present';
    final workingHours = record['working_hours'] as num?;
    final inTime = record['in_time'] as String?;
    final outTime = record['out_time'] as String?;

    final isPresent = status == 'Present';
    final statusColor = isPresent ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: statusColor,
          ),
        ),
        title: Text(_formatDate(date ?? '')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status'),
            if (inTime != null) Text('In: ${_formatTime(inTime)}'),
            if (outTime != null) Text('Out: ${_formatTime(outTime)}'),
            if (workingHours != null) Text('Hours: ${workingHours.toStringAsFixed(1)}h'),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEE, MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final time = DateTime.parse(timeStr);
      return DateFormat('HH:mm').format(time);
    } catch (_) {
      return timeStr;
    }
  }
}

