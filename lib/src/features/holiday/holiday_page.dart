import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'holiday_repository.dart';

final holidaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final holidayRepo = HolidayListRepository(client);
  return holidayRepo.getEmployeeHolidays(employeeId);
});

class HolidayPage extends ConsumerWidget {
  const HolidayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final holidays = ref.watch(holidaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.holidays),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(holidaysProvider.future),
        child: holidays.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No holidays found', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _HolidayCard(holiday: items[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading holidays', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(holidaysProvider),
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

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.holiday});

  final Map<String, dynamic> holiday;

  @override
  Widget build(BuildContext context) {
    final holidayDate = holiday['holiday_date'] as String?;
    final description = holiday['description'] as String? ?? 'Holiday';
    // Handle weekly_off as bool, int (0/1), or string ("0"/"1")
    final weeklyOffValue = holiday['weekly_off'];
    final weeklyOff = weeklyOffValue is bool
        ? weeklyOffValue
        : weeklyOffValue is int
            ? weeklyOffValue == 1
            : weeklyOffValue is String
                ? weeklyOffValue == '1' || weeklyOffValue.toLowerCase() == 'true'
                : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1C4CA5).withOpacity(0.1),
          child: Icon(
            weeklyOff ? Icons.weekend_rounded : Icons.celebration_rounded,
            color: const Color(0xFF1C4CA5),
          ),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          holidayDate != null ? _formatDate(holidayDate) : 'No date',
        ),
        trailing: weeklyOff
            ? Chip(
                label: const Text('Weekly Off'),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.blue, fontSize: 12),
              )
            : null,
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
}

