import '../../core/network/erpnext_repository.dart';

class TodoRepository extends ERPNextRepository {
  TodoRepository(super.client);

  @override
  String get doctype => 'ToDo';

  /// Get pending approvals/todos for the logged-in user
  Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    // Get current user from session
    final userRes = await dio.get('/api/method/frappe.auth.get_logged_user');
    final userId = userRes.data is Map ? userRes.data['message'] as String? : null;
    if (userId == null) return [];
    
    return getPendingApprovalsForUser(userId);
  }

  /// Get pending approvals/todos for a specific user
  Future<List<Map<String, dynamic>>> getPendingApprovalsForUser(String userId) async {
    return list(
      fields: [
        'name',
        'description',
        'reference_type',
        'reference_name',
        'status',
        'priority',
        'allocated_to',
        'assigned_by',
        'creation',
        'modified',
      ],
      filters: [
        ['allocated_to', '=', userId],
        ['status', '!=', 'Closed'],
      ],
      orderBy: 'modified desc',
      limit: 50,
    );
  }

  /// Get all todos (pending + completed)
  Future<List<Map<String, dynamic>>> getAllTodos(String userId) async {
    return list(
      fields: [
        'name',
        'description',
        'reference_type',
        'reference_name',
        'status',
        'priority',
        'allocated_to',
        'assigned_by',
        'creation',
        'modified',
      ],
      filters: [
        ['allocated_to', '=', userId],
      ],
      orderBy: 'modified desc',
      limit: 100,
    );
  }

  /// Close/Complete a todo
  Future<Map<String, dynamic>> closeTodo(String name) async {
    return update(name, {'status': 'Closed'});
  }

  /// Get todo details
  Future<Map<String, dynamic>> getTodoDetails(String name) async {
    return get(name);
  }
}


