import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/erpnext_repository.dart';

class PayslipRepository extends ERPNextRepository {
  PayslipRepository(super.client);

  @override
  String get doctype => 'Salary Slip';

  /// Get payslips for an employee
  Future<List<Map<String, dynamic>>> getEmployeePayslips(String employeeId) async {
    return list(
      fields: [
        'name',
        'employee',
        'employee_name',
        'posting_date',
        'start_date',
        'end_date',
        'total_deduction',
        'total_earning',
        'net_pay',
        'status',
        'company',
      ],
      filters: [
        ['employee', '=', employeeId],
        ['docstatus', '=', 1], // Only submitted payslips
      ],
      orderBy: 'posting_date desc',
      limit: 50,
    );
  }

  /// Get payslip details
  Future<Map<String, dynamic>> getPayslipDetails(String name) async {
    final payslip = await get(name);
    
    // Fetch salary detail tables
    // Note: This might need custom API endpoint if child tables aren't included
    return payslip;
  }

  /// Download payslip PDF (if ERPNext API method exists)
  Future<Uint8List?> downloadPayslipPdf(String name) async {
    try {
      final res = await dio.get(
        '/api/method/frappe.utils.print_format.download_pdf',
        queryParameters: {
          'doctype': doctype,
          'name': name,
          'format': 'Standard',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data as Uint8List?;
    } catch (_) {
      return null;
    }
  }
}

