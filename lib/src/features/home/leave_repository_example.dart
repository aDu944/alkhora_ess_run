import '../../core/network/erpnext_repository.dart';
import '../../core/network/frappe_client.dart';

/// Example repository for Leave Application doctype
/// This demonstrates how to extend ERPNextRepository for a specific doctype
class LeaveRepository extends ERPNextRepository {
  LeaveRepository(super.client);

  @override
  String get doctype => 'Leave Application';

  /// Get all leave applications for current user
  Future<List<Map<String, dynamic>>> getMyLeaves(String userId) async {
    return list(
      fields: ['name', 'employee', 'leave_type', 'from_date', 'to_date', 'total_leave_days', 'status'],
      filters: [
        ['employee', 'in', await _getEmployeeNamesForUser(userId)],
      ],
      orderBy: 'from_date desc',
      limit: 50,
    );
  }

  /// Get pending leave applications
  Future<List<Map<String, dynamic>>> getPendingLeaves(String userId) async {
    return list(
      fields: ['name', 'employee', 'leave_type', 'from_date', 'to_date', 'total_leave_days'],
      filters: [
        ['employee', 'in', await _getEmployeeNamesForUser(userId)],
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
    String? halfDay,
    DateTime? halfDayDate,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().split('T')[0], // Date only
      'to_date': toDate.toIso8601String().split('T')[0],
      if (reason != null) 'reason': reason,
      if (halfDay != null) 'half_day': halfDay,
      if (halfDayDate != null) 'half_day_date': halfDayDate.toIso8601String().split('T')[0],
    };

    return create(payload);
  }

  /// Submit a leave application
  Future<Map<String, dynamic>> submitLeaveApplication(String name) async {
    return submit(name);
  }

  /// Cancel a leave application
  Future<Map<String, dynamic>> cancelLeaveApplication(String name) async {
    return cancel(name);
  }

  /// Helper: Get employee names for a user
  Future<List<String>> _getEmployeeNamesForUser(String userId) async {
    // This would typically use Employee repository
    // Simplified for example
    return [userId]; // In real implementation, fetch from Employee doctype
  }
}

/// Example usage in a controller:
/// 
/// ```dart
/// final client = await ref.read(frappeClientProvider.future);
/// final leaveRepo = LeaveRepository(client);
/// final myLeaves = await leaveRepo.getMyLeaves('john@example.com');
/// ```
/// 
/// Or with a provider:
/// 
/// ```dart
/// final leaveRepositoryProvider = Provider.family<LeaveRepository, FrappeClient>(
///   (ref, client) => LeaveRepository(client),
/// );
/// ```

