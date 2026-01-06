<<<<<<< Current (Your changes)
=======
import 'package:dio/dio.dart';
import 'dart:convert';

import '../../core/network/frappe_client.dart';

class AttendanceRepository {
  AttendanceRepository(this._client);

  final FrappeClient _client;

  Dio get _dio => _client.dio;

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
    return Map<String, dynamic>.from(first as Map);
  }

  Future<String> getEmployeeIdForUser(String user) async {
    final emp = await getEmployeeForUser(user);
    return emp['name'] as String;
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

  Future<List<Map<String, dynamic>>> getCheckins({
    required String employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    bool asc = false,
  }) async {
    final filters = <dynamic>[
      ['employee', '=', employeeId],
      if (from != null && to != null) ['time', 'between', [from.toIso8601String(), to.toIso8601String()]],
      if (from != null && to == null) ['time', '>=', from.toIso8601String()],
      if (from == null && to != null) ['time', '<=', to.toIso8601String()],
    ];

    final res = await _dio.get(
      '/api/resource/Employee Checkin',
      queryParameters: {
        'fields': '["name","log_type","time","device_id","latitude","longitude","location_accuracy"]',
        'filters': jsonEncode(filters),
        'order_by': 'time ${asc ? 'asc' : 'desc'}',
        'limit_page_length': limit,
      },
    );
    final data = (res.data is Map) ? (res.data['data'] as List?) : null;
    if (data == null) return const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<void> createCheckin({
    required String employeeId,
    required String logType, // "IN" | "OUT"
    required DateTime time,
    String? deviceId,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'log_type': logType,
      'time': time.toIso8601String(),
      'device_id': deviceId ?? 'mobile',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'location_accuracy': accuracy,
    };

    try {
      await _dio.post(
        '/api/resource/Employee Checkin',
        data: payload,
        options: idempotencyKey == null || idempotencyKey.isEmpty
            ? null
            : Options(headers: <String, dynamic>{'X-Idempotency-Key': idempotencyKey}),
      );
    } on DioException catch (e) {
      // Some ERPNext setups don't have location fields on Employee Checkin.
      // Retry with minimal standard fields.
      final msg = e.response?.data?.toString() ?? '';
      final looksLikeFieldError =
          msg.contains('Unknown') || msg.contains('unknown') || msg.contains('Field') || msg.contains('field');
      if (looksLikeFieldError && (payload.containsKey('latitude') || payload.containsKey('longitude'))) {
        await _dio.post(
          '/api/resource/Employee Checkin',
          data: <String, dynamic>{
            'employee': employeeId,
            'log_type': logType,
            'time': time.toIso8601String(),
            'device_id': deviceId ?? 'mobile',
          },
          options: idempotencyKey == null || idempotencyKey.isEmpty
              ? null
              : Options(headers: <String, dynamic>{'X-Idempotency-Key': idempotencyKey}),
        );
        return;
      }
      rethrow;
    }
  }
}

>>>>>>> Incoming (Background Agent changes)
