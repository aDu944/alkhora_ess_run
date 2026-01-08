import 'dart:convert';

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
  /// If preferEnglish is true, fetches full record to get English translations
  Future<Map<String, dynamic>> getEmployeeProfile(String employeeId, {bool preferEnglish = false}) async {
    Map<String, dynamic> emp;
    
    // Always fetch full record to ensure we have all fields
    emp = await get(employeeId);
    
    // If English is preferred, try to get English translation
    if (preferEnglish) {
      // Check if employee_name_english field exists in the full record
      if (emp['employee_name_english'] == null || (emp['employee_name_english'] as String?)?.isEmpty == true) {
        // Try to get English translation from Translation doctype
        try {
          final arabicName = emp['employee_name'] as String?;
          if (arabicName != null && arabicName.isNotEmpty) {
            final dio = this.dio;
            final translationRes = await dio.get(
              '/api/resource/Translation',
              queryParameters: {
                'fields': jsonEncode(['translated_text', 'source_text']),
                'filters': jsonEncode([
                  ['source_text', '=', arabicName],
                  ['language', '=', 'en'],
                  ['contributed', '=', 0],
                ]),
                'limit_page_length': 10,
              },
            );
            final translationData = (translationRes.data is Map) ? (translationRes.data['data'] as List?) : null;
            if (translationData != null && translationData.isNotEmpty) {
              for (final translation in translationData) {
                if (translation is Map) {
                  final sourceText = translation['source_text'] as String?;
                  if (sourceText == arabicName) {
                    emp['employee_name_english'] = translation['translated_text'] as String?;
                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          // Ignore translation errors, fall back to Arabic name
        }
      }
    }
    
    // Use English name if available and preferred, otherwise use Arabic
    final displayName = (preferEnglish && emp['employee_name_english'] != null && 
                        (emp['employee_name_english'] as String?)?.isNotEmpty == true)
        ? emp['employee_name_english'] as String
        : emp['employee_name'] as String?;
    
    // Return only fields needed for profile
    return {
      'name': emp['name'],
      'employee_name': displayName ?? '—',
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


