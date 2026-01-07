# ERPNext API Quick Reference

## Endpoint Patterns

```
GET    /api/resource/{DocType}                    # List records
GET    /api/resource/{DocType}/{name}             # Get single record
POST   /api/resource/{DocType}                    # Create record
PUT    /api/resource/{DocType}/{name}             # Update record
DELETE /api/resource/{DocType}/{name}             # Delete record
```

## Query Parameters (GET)

| Parameter | Type | Example | Description |
|-----------|------|---------|-------------|
| `fields` | JSON array | `["name","employee_name"]` | Fields to return |
| `filters` | JSON array | `[["status","=","Open"]]` | Filter conditions |
| `order_by` | String | `"time desc"` | Sort order |
| `limit_page_length` | Number | `20` | Max records |
| `limit_start` | Number | `0` | Pagination offset |

## Filter Operators

- `=` - Equal
- `!=` - Not equal
- `>` - Greater than
- `<` - Less than
- `>=` - Greater or equal
- `<=` - Less or equal
- `like` - Contains (SQL LIKE)
- `not like` - Not contains
- `in` - In list
- `not in` - Not in list

## Filter Examples

```dart
// Single condition
[["status", "=", "Open"]]

// Multiple AND conditions
[["employee", "=", "EMP-001"], ["time", ">=", "2024-01-01"]]

// IN operator
[["employee", "in", ["EMP-001", "EMP-002"]]]

// Date range
[["from_date", ">=", "2024-01-01"], ["to_date", "<=", "2024-12-31"]]
```

## Using the Base Repository

```dart
// 1. Extend ERPNextRepository
class MyDocTypeRepository extends ERPNextRepository {
  MyDocTypeRepository(super.client);
  @override
  String get doctype => 'My DocType';
}

// 2. Use in your code
final client = await ref.read(frappeClientProvider.future);
final repo = MyDocTypeRepository(client);

// 3. CRUD operations
final record = await repo.get('DOC-001');
final list = await repo.list(filters: [['status', '=', 'Active']]);
final created = await repo.create({'field1': 'value1'});
final updated = await repo.update('DOC-001', {'field1': 'new value'});
await repo.delete('DOC-001');
```

## Direct Dio Usage (Current Pattern)

```dart
class MyRepository {
  MyRepository(this._client);
  final FrappeClient _client;
  Dio get _dio => _client.dio;

  Future<List<Map<String, dynamic>>> getRecords() async {
    final res = await _dio.get(
      '/api/resource/My DocType',
      queryParameters: {
        'fields': '["name","title","status"]',
        'filters': '[["status","=","Active"]]',
        'order_by': 'modified desc',
        'limit_page_length': 20,
      },
    );
    final data = res.data['data'] as List?;
    return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  Future<void> createRecord(Map<String, dynamic> payload) async {
    await _dio.post('/api/resource/My DocType', data: payload);
  }
}
```

## Common Doctypes

- `Employee` - Employee master
- `Employee Checkin` - Attendance logs
- `Attendance` - Processed attendance
- `Leave Application` - Leave requests
- `Leave Allocation` - Leave balances
- `Expense Claim` - Expense submissions
- `Salary Slip` - Payslips
- `ToDo` - Tasks/approvals
- `Announcement` - Company announcements
- `Holiday List` - Holiday calendar

## Date/Time Format

```dart
// ISO 8601 for datetime
DateTime.now().toIso8601String()  // "2024-01-15T10:30:00.000Z"

// Date only (YYYY-MM-DD)
DateTime.now().toIso8601String().split('T')[0]  // "2024-01-15"
```

## Error Handling

```dart
try {
  await _dio.post('/api/resource/MyDocType', data: payload);
} on DioException catch (e) {
  final errorMsg = e.response?.data?['_error_message'] ?? 'Unknown error';
  throw StateError(errorMsg);
}
```


