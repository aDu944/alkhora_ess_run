import '../../core/network/erpnext_repository.dart';
import '../../core/network/frappe_client.dart';

class LeaveRepository extends ERPNextRepository {
  LeaveRepository(super.client);

  @override
  String get doctype => 'Leave Application';

  /// Get all leave applications for an employee
  Future<List<Map<String, dynamic>>> getEmployeeLeaves(String employeeId) async {
    return list(
      fields: [
        'name',
        'employee',
        'employee_name',
        'leave_type',
        'from_date',
        'to_date',
        'total_leave_days',
        'status',
        'reason',
        'half_day',
        'half_day_date',
        'posting_date',
      ],
      filters: [
        ['employee', '=', employeeId],
      ],
      orderBy: 'from_date desc',
      limit: 100,
    );
  }

  /// Get pending leave applications
  Future<List<Map<String, dynamic>>> getPendingLeaves(String employeeId) async {
    return list(
      fields: [
        'name',
        'leave_type',
        'from_date',
        'to_date',
        'total_leave_days',
        'status',
        'reason',
      ],
      filters: [
        ['employee', '=', employeeId],
        ['status', '=', 'Open'],
      ],
      orderBy: 'from_date asc',
    );
  }

  /// Create a new leave application
  Future<Map<String, dynamic>> applyForLeave({
    required String employeeId,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    String? reason,
    bool? halfDay,
    DateTime? halfDayDate,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (halfDay == true) 'half_day': 1,
      if (halfDayDate != null) 'half_day_date': halfDayDate.toIso8601String().split('T')[0],
    };

    return create(payload);
  }

  /// Submit a leave application
  Future<Map<String, dynamic>> submitLeave(String name) async {
    return submit(name);
  }
}

/// Leave Allocation Repository
class LeaveAllocationRepository extends ERPNextRepository {
  LeaveAllocationRepository(super.client);

  @override
  String get doctype => 'Leave Allocation';

  /// Get leave balances for an employee
  Future<List<Map<String, dynamic>>> getLeaveBalances(String employeeId) async {
    return list(
      fields: [
        'name',
        'employee',
        'leave_type',
        'from_date',
        'to_date',
        'total_leaves_allocated',
        'unused_leaves',
        'expired_leaves',
        'new_leaves_allocated',
      ],
      filters: [
        ['employee', '=', employeeId],
        ['docstatus', '=', 1], // Only submitted allocations
      ],
      orderBy: 'from_date desc',
    );
  }

  /// Get available leave types for an employee
  Future<List<Map<String, dynamic>>> getAvailableLeaveTypes(String employeeId) async {
    // Get leave types from allocations
    final allocations = await getLeaveBalances(employeeId);
    final leaveTypes = <String, Map<String, dynamic>>{};
    
    for (final alloc in allocations) {
      final leaveType = alloc['leave_type'] as String?;
      if (leaveType != null && !leaveTypes.containsKey(leaveType)) {
        leaveTypes[leaveType] = alloc;
      }
    }
    
    return leaveTypes.values.toList();
  }
}

/// Leave Type Repository
class LeaveTypeRepository extends ERPNextRepository {
  LeaveTypeRepository(super.client);

  @override
  String get doctype => 'Leave Type';

  /// Get all active leave types
  Future<List<Map<String, dynamic>>> getActiveLeaveTypes() async {
    return list(
      fields: [
        'name',
        'leave_type_name',
        'max_leaves_allowed',
        'is_optional_leave',
        'is_compensatory',
        'is_carry_forward',
      ],
      filters: [
        ['is_active', '=', 1],
      ],
      orderBy: 'leave_type_name asc',
    );
  }
}


