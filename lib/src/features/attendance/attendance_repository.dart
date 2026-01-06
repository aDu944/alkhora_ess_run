import '../../core/network/erpnext_repository.dart';

class AttendanceRepository extends ERPNextRepository {
  AttendanceRepository(super.client);

  @override
  String get doctype => 'Attendance';

  /// Get attendance records for an employee
  Future<List<Map<String, dynamic>>> getEmployeeAttendance({
    required String employeeId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    final filters = <List<dynamic>>[
      ['employee', '=', employeeId],
      ['docstatus', '=', 1], // Only submitted attendance
    ];

    if (fromDate != null) {
      filters.add(['attendance_date', '>=', fromDate.toIso8601String().split('T')[0]]);
    }
    if (toDate != null) {
      filters.add(['attendance_date', '<=', toDate.toIso8601String().split('T')[0]]);
    }

    return list(
      fields: [
        'name',
        'employee',
        'employee_name',
        'attendance_date',
        'status',
        'working_hours',
        'in_time',
        'out_time',
        'late_entry',
        'early_exit',
      ],
      filters: filters,
      orderBy: 'attendance_date desc',
      limit: limit ?? 50,
    );
  }

  /// Get attendance for current month
  Future<List<Map<String, dynamic>>> getCurrentMonthAttendance(String employeeId) async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    return getEmployeeAttendance(
      employeeId: employeeId,
      fromDate: firstDay,
      toDate: lastDay,
    );
  }
}

