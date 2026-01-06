import '../../core/network/erpnext_repository.dart';

class EmployeeRepository extends ERPNextRepository {
  EmployeeRepository(super.client);

  @override
  String get doctype => 'Employee';

  /// Get employee details
  Future<Map<String, dynamic>> getEmployee(String employeeId) async {
    return get(employeeId);
  }

  /// Update employee details (only allowed fields)
  Future<Map<String, dynamic>> updateEmployeeDetails(
    String employeeId,
    Map<String, dynamic> updates,
  ) async {
    // Only allow updating certain fields for security
    final allowedFields = [
      'cell_number',
      'personal_email',
      'preferred_email',
      'emergency_phone_number',
      'alternate_phone_number',
      'current_address',
      'permanent_address',
      'personal_mobile',
      'preferred_contact_email',
    ];

    final safeUpdates = <String, dynamic>{};
    for (final key in allowedFields) {
      if (updates.containsKey(key)) {
        safeUpdates[key] = updates[key];
      }
    }

    if (safeUpdates.isEmpty) {
      throw StateError('No allowed fields to update');
    }

    return update(employeeId, safeUpdates);
  }

  /// Get employee info for profile display
  Future<Map<String, dynamic>> getEmployeeProfile(String employeeId) async {
    final emp = await get(employeeId);
    
    // Return only fields needed for profile
    return {
      'name': emp['name'],
      'employee_name': emp['employee_name'],
      'designation': emp['designation'],
      'department': emp['department'],
      'branch': emp['branch'],
      'company': emp['company'],
      'date_of_joining': emp['date_of_joining'],
      'cell_number': emp['cell_number'],
      'personal_email': emp['personal_email'],
      'preferred_email': emp['preferred_email'],
      'emergency_phone_number': emp['emergency_phone_number'],
      'current_address': emp['current_address'],
      'permanent_address': emp['permanent_address'],
      'image': emp['image'],
      'user_id': emp['user_id'],
    };
  }
}

