import '../../core/network/erpnext_repository.dart';

class ExpenseRepository extends ERPNextRepository {
  ExpenseRepository(super.client);

  @override
  String get doctype => 'Expense Claim';

  /// Get expense claims for an employee
  Future<List<Map<String, dynamic>>> getEmployeeExpenses(String employeeId) async {
    return list(
      fields: [
        'name',
        'employee',
        'employee_name',
        'posting_date',
        'total_claimed_amount',
        'total_sanctioned_amount',
        'status',
        'company',
        'expense_approver',
      ],
      filters: [
        ['employee', '=', employeeId],
      ],
      orderBy: 'posting_date desc',
      limit: 50,
    );
  }

  /// Create a new expense claim
  Future<Map<String, dynamic>> createExpenseClaim({
    required String employeeId,
    required List<Map<String, dynamic>> expenses,
    String? title,
    DateTime? postingDate,
  }) async {
    final payload = <String, dynamic>{
      'employee': employeeId,
      'expenses': expenses,
      if (title != null) 'title': title,
      if (postingDate != null) 'posting_date': postingDate.toIso8601String().split('T')[0],
    };

    return create(payload);
  }

  /// Submit an expense claim
  Future<Map<String, dynamic>> submitExpenseClaim(String name) async {
    return submit(name);
  }

  /// Get expense claim details with expense items
  Future<Map<String, dynamic>> getExpenseDetails(String name) async {
    return get(name);
  }
}

/// Expense Claim Type Repository
class ExpenseTypeRepository extends ERPNextRepository {
  ExpenseTypeRepository(super.client);

  @override
  String get doctype => 'Expense Claim Type';

  /// Get all active expense types
  Future<List<Map<String, dynamic>>> getActiveExpenseTypes() async {
    return list(
      fields: [
        'name',
        'expense_type',
        'description',
      ],
      filters: [
        ['disabled', '=', 0],
      ],
      orderBy: 'expense_type asc',
    );
  }
}


