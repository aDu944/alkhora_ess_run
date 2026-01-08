import '../../core/network/erpnext_repository.dart';

class HolidayListRepository extends ERPNextRepository {
  HolidayListRepository(super.client);

  @override
  String get doctype => 'Holiday List';

  /// Get all holiday lists
  Future<List<Map<String, dynamic>>> getAllHolidayLists() async {
    return list(
      fields: [
        'name',
        'holiday_list_name',
        'from_date',
        'to_date',
        'total_holidays',
      ],
      orderBy: 'from_date desc',
    );
  }

  /// Get holidays for a specific holiday list
  Future<List<Map<String, dynamic>>> getHolidays(String holidayListName) async {
    // Get the holiday list first
    final holidayList = await get(holidayListName);
    
    // Note: Holiday dates are typically in child table "holidays"
    // This might require custom API or fetching child table separately
    // For now, return the holiday list with dates if available
    return [holidayList];
  }

  /// Get holidays for current year
  Future<List<Map<String, dynamic>>> getCurrentYearHolidays() async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31);

    final lists = await list(
      filters: [
        ['from_date', '<=', yearEnd.toIso8601String().split('T')[0]],
        ['to_date', '>=', yearStart.toIso8601String().split('T')[0]],
      ],
    );

    // If holiday dates are in child table, we'd need to fetch them separately
    // This is a simplified version
    return lists;
  }

  /// Get holidays for an employee (from their assigned holiday list)
  Future<List<Map<String, dynamic>>> getEmployeeHolidays(String employeeId) async {
    try {
      // First, get employee's holiday list
      final empRes = await dio.get(
        '/api/resource/Employee/$employeeId',
        queryParameters: {'fields': '["holiday_list"]'},
      );
      final empData = empRes.data is Map ? empRes.data['data'] : null;
      final holidayListName = empData is Map ? empData['holiday_list'] as String? : null;

      if (holidayListName == null || holidayListName.isEmpty) {
        return [];
      }

      // Try to fetch holidays from Holiday doctype (if accessible)
      try {
        final holidayRes = await dio.get(
          '/api/resource/Holiday',
          queryParameters: {
            'fields': '["holiday_date","description","weekly_off"]',
            'filters': '[["parent","=","$holidayListName"]]',
            'order_by': 'holiday_date asc',
          },
        );
        final holidayData = holidayRes.data is Map ? holidayRes.data['data'] : null;
        if (holidayData is List && holidayData.isNotEmpty) {
          return holidayData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {
        // Holiday doctype might not be accessible, try alternative
      }

      // Fallback: return holiday list info
      final holidayList = await get(holidayListName);
      return [holidayList];
    } catch (e) {
      return [];
    }
  }
}

/// For fetching holiday dates from Holiday doctype if needed
/// Note: Holidays are usually stored as child table of Holiday List
/// You might need a custom API endpoint to fetch them efficiently


