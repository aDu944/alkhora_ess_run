import 'dart:convert';

import 'package:dio/dio.dart';
import 'frappe_client.dart';

/// Base repository class for ERPNext doctype operations.
/// 
/// This provides common CRUD operations for any ERPNext doctype.
/// Extend this class for specific doctypes.
abstract class ERPNextRepository {
  ERPNextRepository(this.client);

  final FrappeClient client;
  Dio get dio => client.dio;

  /// Get the doctype name this repository works with
  String get doctype;

  /// Get a single record by name
  Future<Map<String, dynamic>> get(String name) async {
    final res = await dio.get('/api/resource/$doctype/$name');
    final data = res.data is Map ? res.data['data'] : null;
    if (data == null) throw StateError('Record not found: $name');
    return Map<String, dynamic>.from(data as Map);
  }

  /// List records with optional filters, fields, ordering, and pagination
  Future<List<Map<String, dynamic>>> list({
    List<String>? fields,
    List<List<dynamic>>? filters,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};

    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = jsonEncode(fields);
    }

    if (filters != null && filters.isNotEmpty) {
      queryParams['filters'] = jsonEncode(filters);
    }

    if (orderBy != null) {
      queryParams['order_by'] = orderBy;
    }

    if (limit != null) {
      queryParams['limit_page_length'] = limit;
    }

    if (offset != null) {
      queryParams['limit_start'] = offset;
    }

    final res = await dio.get('/api/resource/$doctype', queryParameters: queryParams);
    final data = res.data is Map ? res.data['data'] : null;
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Create a new record
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await dio.post('/api/resource/$doctype', data: data);
    final responseData = res.data is Map ? res.data['data'] : null;
    if (responseData == null) throw StateError('Failed to create record');
    return Map<String, dynamic>.from(responseData as Map);
  }

  /// Update an existing record
  Future<Map<String, dynamic>> update(String name, Map<String, dynamic> data) async {
    final res = await dio.put('/api/resource/$doctype/$name', data: data);
    final responseData = res.data is Map ? res.data['data'] : null;
    if (responseData == null) throw StateError('Failed to update record: $name');
    return Map<String, dynamic>.from(responseData as Map);
  }

  /// Delete a record
  Future<void> delete(String name) async {
    await dio.delete('/api/resource/$doctype/$name');
  }

  /// Submit a record (if workflow is enabled)
  Future<Map<String, dynamic>> submit(String name) async {
    final res = await dio.post('/api/resource/$doctype/$name/submit');
    final responseData = res.data is Map ? res.data['data'] : null;
    if (responseData == null) throw StateError('Failed to submit record: $name');
    return Map<String, dynamic>.from(responseData as Map);
  }

  /// Cancel a submitted record
  Future<Map<String, dynamic>> cancel(String name) async {
    final res = await dio.post('/api/resource/$doctype/$name', data: {'docstatus': 2});
    final responseData = res.data is Map ? res.data['data'] : null;
    if (responseData == null) throw StateError('Failed to cancel record: $name');
    return Map<String, dynamic>.from(responseData as Map);
  }
}


