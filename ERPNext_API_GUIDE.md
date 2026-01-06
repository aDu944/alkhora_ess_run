# ERPNext Doctype API Integration Guide

This guide explains how to wire ERPNext doctype APIs in the Flutter app.

## Overview

ERPNext uses REST APIs to interact with doctypes. The app uses a `FrappeClient` wrapper around Dio that handles:
- Session cookie management
- Base URL configuration
- Request/response formatting

## Base Endpoints

### Authentication
- `POST /api/method/login` - Login (form-encoded: `usr`, `pwd`)
- `GET /api/method/logout` - Logout
- `GET /api/method/frappe.auth.get_logged_user` - Get current user

### Resource API (Doctypes)
- `GET /api/resource/{DocType}` - List/query doctype records
- `GET /api/resource/{DocType}/{name}` - Get single record by name
- `POST /api/resource/{DocType}` - Create new record
- `PUT /api/resource/{DocType}/{name}` - Update existing record
- `DELETE /api/resource/{DocType}/{name}` - Delete record

## Query Parameters (GET requests)

### `fields`
JSON array of field names to return:
```dart
'fields': '["name", "employee_name", "user_id"]'
```

### `filters`
JSON array of filter conditions:
```dart
// Single condition
'filters': '[["user_id","=","john@example.com"]]'

// Multiple conditions (AND)
'filters': '[[\"employee\",\"=\",\"EMP-001\"],[\"time\",\">=\",\"2024-01-01\"]]'

// Operators: =, !=, >, <, >=, <=, like, not like, in, not in
```

### `order_by`
Sort order:
```dart
'order_by': 'time desc'  // or 'time asc'
```

### `limit_page_length`
Limit number of records:
```dart
'limit_page_length': 20
```

### `limit_start`
Pagination offset:
```dart
'limit_start': 0  // Start from first record
```

## Example Patterns

### 1. Get Single Record
```dart
Future<Map<String, dynamic>> getRecord(String doctype, String name) async {
  final res = await _dio.get('/api/resource/$doctype/$name');
  return Map<String, dynamic>.from(res.data['data'] as Map);
}
```

### 2. List Records with Filters
```dart
Future<List<Map<String, dynamic>>> listRecords({
  required String doctype,
  List<String>? fields,
  List<List<dynamic>>? filters,
  String? orderBy,
  int? limit,
}) async {
  final queryParams = <String, dynamic>{};
  
  if (fields != null) {
    queryParams['fields'] = jsonEncode(fields);
  }
  
  if (filters != null) {
    queryParams['filters'] = jsonEncode(filters);
  }
  
  if (orderBy != null) {
    queryParams['order_by'] = orderBy;
  }
  
  if (limit != null) {
    queryParams['limit_page_length'] = limit;
  }
  
  final res = await _dio.get('/api/resource/$doctype', queryParameters: queryParams);
  final data = res.data['data'] as List?;
  return data?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
}
```

### 3. Create Record
```dart
Future<Map<String, dynamic>> createRecord({
  required String doctype,
  required Map<String, dynamic> data,
}) async {
  final res = await _dio.post('/api/resource/$doctype', data: data);
  return Map<String, dynamic>.from(res.data['data'] as Map);
}
```

### 4. Update Record
```dart
Future<Map<String, dynamic>> updateRecord({
  required String doctype,
  required String name,
  required Map<String, dynamic> data,
}) async {
  final res = await _dio.put('/api/resource/$doctype/$name', data: data);
  return Map<String, dynamic>.from(res.data['data'] as Map);
}
```

### 5. Delete Record
```dart
Future<void> deleteRecord(String doctype, String name) async {
  await _dio.delete('/api/resource/$doctype/$name');
}
```

## Current Implementation Example

See `lib/src/features/home/attendance_repository.dart` for a complete example:

```dart
class AttendanceRepository {
  AttendanceRepository(this._client);
  final FrappeClient _client;
  Dio get _dio => _client.dio;

  // Get employee for user
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
    if (first?['name'] == null) {
      throw StateError('No Employee found');
    }
    return Map<String, dynamic>.from(first!);
  }

  // Create checkin
  Future<void> createCheckin({
    required String employeeId,
    required String logType,
    required DateTime time,
  }) async {
    await _dio.post('/api/resource/Employee Checkin', data: {
      'employee': employeeId,
      'log_type': logType,
      'time': time.toIso8601String(),
    });
  }
}
```

## Common Doctypes You Might Use

1. **Employee** - Employee master data
2. **Employee Checkin** - Attendance check-in/out records
3. **Attendance** - Processed attendance records
4. **Leave Application** - Leave requests
5. **Expense Claim** - Expense submissions
6. **Salary Slip** - Payslip records
7. **ToDo** - Tasks/approvals
8. **Employee Advance** - Advance requests
9. **Announcement** - Company announcements
10. **Holiday List** - Holiday calendar

## Error Handling

ERPNext returns errors in this format:
```json
{
  "exc": "...",
  "exc_type": "...",
  "exception": "...",
  "_error_message": "Error message"
}
```

Handle with try-catch:
```dart
try {
  await _dio.post('/api/resource/SomeDocType', data: payload);
} on DioException catch (e) {
  final errorData = e.response?.data;
  final message = errorData?['_error_message'] ?? 'Unknown error';
  throw StateError(message);
}
```

## Date/Time Format

ERPNext expects ISO 8601 format:
```dart
DateTime.now().toIso8601String()  // "2024-01-15T10:30:00.000Z"
```

## Best Practices

1. **Create Repository Classes** - One per major doctype (e.g., `LeaveRepository`, `ExpenseRepository`)
2. **Use Type-Safe Models** - Create Dart classes for doctype records
3. **Handle Offline Scenarios** - Queue mutations when offline
4. **Validate Server Responses** - Check for `data` key and null safety
5. **Use Filters Efficiently** - Filter on server side rather than client
6. **Handle Pagination** - Use `limit_start` and `limit_page_length` for large datasets

## Permissions

Ensure the logged-in user has proper permissions in ERPNext:
- **Read** permission to query doctypes
- **Write** permission to create/update records
- **Submit** permission if workflow is enabled

Check permissions in ERPNext: Setup → Users → Permissions → Role Permissions Manager

