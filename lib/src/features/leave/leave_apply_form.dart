import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'leave_repository.dart' show LeaveRepository, LeaveAllocationRepository, LeaveTypeRepository;

final leaveTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  // Try to get leave types from Leave Type doctype first (most reliable)
  try {
    final leaveTypeRepo = LeaveTypeRepository(client);
    final allTypes = await leaveTypeRepo.getActiveLeaveTypes();
    
    // If we got types, try to enrich with allocation balances if available
    try {
      final leaveAllocRepo = LeaveAllocationRepository(client);
      final allocations = await leaveAllocRepo.getLeaveBalances(employeeId);
      final allocationMap = <String, Map<String, dynamic>>{};
      
      for (final alloc in allocations) {
        final leaveType = alloc['leave_type'] as String?;
        if (leaveType != null) {
          allocationMap[leaveType] = alloc;
        }
      }
      
      // Enrich leave types with balance information if available
      return allTypes.map((type) {
        final typeName = (type['name'] as String?) ?? (type['leave_type_name'] as String?) ?? '';
        final alloc = allocationMap[typeName];
        if (alloc != null) {
          return {
            ...type,
            'leave_type': typeName,
            'unused_leaves': alloc['unused_leaves'] ?? 0,
          };
        } else {
          return {
            ...type,
            'leave_type': typeName,
            'unused_leaves': 0,
          };
        }
      }).toList();
    } catch (e) {
      // If allocation fetch fails, return types without balances
      debugPrint('Could not fetch leave balances: $e');
      return allTypes.map((type) {
        final typeName = (type['name'] as String?) ?? (type['leave_type_name'] as String?) ?? '';
        return {
          ...type,
          'leave_type': typeName,
          'unused_leaves': 0,
        };
      }).toList();
    }
  } catch (e) {
    debugPrint('Error fetching leave types from Leave Type doctype: $e');
    // Fallback: try to get from allocations only
    try {
      final leaveAllocRepo = LeaveAllocationRepository(client);
      return leaveAllocRepo.getAvailableLeaveTypes(employeeId);
    } catch (e2) {
      debugPrint('Fallback to allocations also failed: $e2');
      return [];
    }
  }
});

class LeaveApplyForm extends ConsumerStatefulWidget {
  const LeaveApplyForm({super.key});

  @override
  ConsumerState<LeaveApplyForm> createState() => _LeaveApplyFormState();
}

class _LeaveApplyFormState extends ConsumerState<LeaveApplyForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLeaveType;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonController = TextEditingController();
  bool _isHalfDay = false;
  DateTime? _halfDayDate;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate 
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLeaveType == null || _fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final client = await ref.read(frappeClientProvider.future);
      final employeeId = await ref.read(employeeIdProvider.future);
      final leaveRepo = LeaveRepository(client);

      await leaveRepo.applyForLeave(
        employeeId: employeeId,
        leaveType: _selectedLeaveType!,
        fromDate: _fromDate!,
        toDate: _toDate!,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        halfDay: _isHalfDay,
        halfDayDate: _halfDayDate,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted successfully')),
        );
        // Invalidate leave-related providers to refresh the list
        // Note: leaveApplicationsProvider is defined in leave_page.dart to avoid circular imports
        // The parent page will handle refreshing when it receives the result
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texts(ref);
    final leaveTypes = ref.watch(leaveTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Leave Type
              leaveTypes.when(
                data: (types) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedLeaveType,
                  isExpanded: true,
                  items: types.map((type) {
                    final name = type['leave_type'] as String? ?? 'Unknown';
                    final balance = type['unused_leaves'] as num? ?? 0;
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(
                        '$name (${balance.toStringAsFixed(0)} days)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedLeaveType = value),
                  validator: (value) => value == null ? 'Please select a leave type' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading leave types'),
              ),
              const SizedBox(height: 16),

              // From Date
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _fromDate != null
                        ? DateFormat('MMM d, yyyy').format(_fromDate!)
                        : 'Select date',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // To Date
              InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'To Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _toDate != null
                        ? DateFormat('MMM d, yyyy').format(_toDate!)
                        : 'Select date',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Half Day
              CheckboxListTile(
                title: const Text('Half Day'),
                value: _isHalfDay,
                onChanged: (value) => setState(() => _isHalfDay = value ?? false),
              ),
              if (_isHalfDay) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _halfDayDate ?? _fromDate ?? DateTime.now(),
                      firstDate: _fromDate ?? DateTime.now(),
                      lastDate: _toDate ?? DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _halfDayDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Half Day Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _halfDayDate != null
                          ? DateFormat('MMM d, yyyy').format(_halfDayDate!)
                          : 'Select date',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for leave',
                ),
                maxLines: 4,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1C4CA5),
                ),
                child: const Text(
                  'Submit Leave Application',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

