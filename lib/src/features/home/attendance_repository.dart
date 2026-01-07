import 'package:dio/dio.dart';

import '../../core/network/frappe_client.dart';

class AttendanceRepository {
  AttendanceRepository(this._client);

  final FrappeClient _client;

  Dio get _dio => _client.dio;

  Future<String> getEmployeeIdForUser(String user) async {
    final emp = await getEmployeeForUser(user);
    return emp['name'] as String;
  }

  Future<Map<String, dynamic>> getEmployeeForUser(String user) async {
    final res = await _dio.get(
      '/api/resource/Employee',
      queryParameters: {
        'fields': '["name","employee_name","user_id"]',
        'filters': '[["user_id","=","$user"]]',
        'limit_page_length': 1,
      },
    );
    final data = (res.data is Map) ? (res.data['data'] as List?) : null;
    final first = (data != null && data.isNotEmpty) ? data.first as Map : null;
    final id = first?['name'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('No Employee linked to user_id=$user');
    }
    return Map<String, dynamic>.from(first!);
  }

  Future<List<Map<String, dynamic>>> getCheckins({
    required String employeeId,
    required DateTime from,
    required DateTime to,
    int limit = 200,
    bool asc = true,
  }) async {
    final res = await _dio.get(
      '/api/resource/Employee Checkin',
      queryParameters: {
        'fields': '["name","log_type","time"]',
        'filters': '[[\"employee\",\"=\",\"$employeeId\"],[\"time\",\">=\",\"${from.toIso8601String()}\"],[\"time\",\"<=\",\"${to.toIso8601String()}\"]]',
        'order_by': asc ? 'time asc' : 'time desc',
        'limit_page_length': limit,
      },
    );
    final data = (res.data is Map) ? (res.data['data'] as List?) : null;
    if (data == null) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> getLastCheckin(String employeeId) async {
    final res = await _dio.get(
      '/api/resource/Employee Checkin',
      queryParameters: {
        'fields': '["name","log_type","time"]',
        'filters': '[["employee","=","$employeeId"]]',
        'order_by': 'time desc',
        'limit_page_length': 1,
      },
    );
    final data = (res.data is Map) ? (res.data['data'] as List?) : null;
    if (data == null || data.isEmpty) return null;
    return Map<String, dynamic>.from(data.first as Map);
  }

  Future<void> createCheckin({
    required String employeeId,
    required String logType, // "IN" | "OUT"
    required DateTime time,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'log_type': logType,
      'time': time.toIso8601String(),
      'device_id': 'mobile',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'location_accuracy': accuracy,
    };

    try {
      await _dio.post('/api/resource/Employee Checkin', data: payload);
    } on DioException catch (e) {
      // Extract error message from response
      String errorMsg = 'Unknown error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          errorMsg = data['_error_message'] as String? ?? 
                     data['exception'] as String? ??
                     data['message'] as String? ??
                     data.toString();
        } else {
          errorMsg = data.toString();
        }
      } else if (e.message != null) {
        errorMsg = e.message!;
      }
      
      // Some ERPNext setups don't have location fields on Employee Checkin.
      // Retry with minimal standard fields.
      final looksLikeFieldError =
          errorMsg.contains('Unknown') || errorMsg.contains('unknown') || 
          errorMsg.contains('Field') || errorMsg.contains('field');
      if (looksLikeFieldError && (payload.containsKey('latitude') || payload.containsKey('longitude'))) {
        try {
          await _dio.post(
            '/api/resource/Employee Checkin',
            data: <String, dynamic>{
              'employee': employeeId,
              'log_type': logType,
              'time': time.toIso8601String(),
            },
          );
          return;
        } on DioException catch (e2) {
          // If retry also fails, use the retry error
          final retryMsg = e2.response?.data?['_error_message'] ?? e2.message ?? errorMsg;
          throw StateError('api_error: $retryMsg');
        }
      }
      
      // Convert DioException to StateError with readable message
      throw StateError('api_error: $errorMsg');
    } catch (e) {
      // If it's already a StateError, rethrow it
      if (e is StateError) rethrow;
      // Otherwise wrap it
      throw StateError('checkin_failed: ${e.toString()}');
    }
  }
}

