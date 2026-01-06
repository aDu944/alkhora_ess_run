import '../../core/network/erpnext_repository.dart';

class AnnouncementRepository extends ERPNextRepository {
  AnnouncementRepository(super.client);

  @override
  String get doctype => 'Announcement';

  /// Get all active announcements
  Future<List<Map<String, dynamic>>> getActiveAnnouncements() async {
    final now = DateTime.now().toIso8601String().split('T')[0];
    
    return list(
      fields: [
        'name',
        'title',
        'message',
        'company',
        'departments',
        'designation',
        'employee',
        'employee_group',
        'expires_on',
        'publish',
      ],
      filters: [
        ['publish', '=', 1],
        ['expires_on', '>=', now],
      ],
      orderBy: 'modified desc',
      limit: 50,
    );
  }

  /// Get announcements for specific employee/department
  Future<List<Map<String, dynamic>>> getRelevantAnnouncements({
    String? employeeId,
    String? department,
    String? designation,
  }) async {
    final announcements = await getActiveAnnouncements();
    
    // Filter on client side based on employee context
    // ERPNext filters might be more complex, so we filter client-side
    return announcements.where((announcement) {
      // Check if announcement is for all employees
      final forAll = announcement['employee'] == null && 
                     announcement['departments'] == null &&
                     announcement['employee_group'] == null;
      
      if (forAll) return true;
      
      // Check employee match
      if (employeeId != null && announcement['employee'] == employeeId) {
        return true;
      }
      
      // Add more filtering logic as needed
      return false;
    }).toList();
  }
}

