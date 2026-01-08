import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../core/network/erpnext_repository.dart';

class PayslipRepository extends ERPNextRepository {
  PayslipRepository(super.client);

  @override
  String get doctype => 'Salary Slip';

  /// Get payslips for an employee
  Future<List<Map<String, dynamic>>> getEmployeePayslips(String employeeId) async {
    try {
      return await list(
        fields: [
          'name',
          'employee',
          'employee_name',
          'posting_date',
          'start_date',
          'end_date',
          // Removed 'total_deduction', 'total_earning' - not permitted for Employee role
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
    } on DioException catch (e) {
      debugPrint('Error fetching payslips: ${e.response?.data}');
      // If docstatus or field permission error, try with minimal fields
      if (e.response?.statusCode == 400 || e.response?.statusCode == 417 || e.response?.statusCode == 500) {
        try {
          return await list(
            fields: [
              'name',
              'employee',
              'employee_name',
              'posting_date',
              'start_date',
              'end_date',
              'net_pay',
              'status',
            ],
            filters: [
              ['employee', '=', employeeId],
            ],
            orderBy: 'posting_date desc',
            limit: 50,
          );
        } catch (e2) {
          debugPrint('Retry with minimal fields also failed: $e2');
          // Return empty list instead of throwing to prevent crashes
          return [];
        }
      }
      // Return empty list on permission errors instead of throwing
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching payslips: $e');
      // Return empty list instead of throwing to prevent crashes
      return [];
    }
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

