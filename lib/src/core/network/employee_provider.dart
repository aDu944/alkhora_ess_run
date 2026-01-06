import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/home/attendance_repository.dart';
import 'providers.dart';

/// Provider to get employee ID for current user
final employeeIdProvider = FutureProvider<String>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final auth = ref.watch(authControllerProvider).valueOrNull;
  if (auth == null) throw StateError('Not authenticated');

  final repo = AttendanceRepository(client);
  return repo.getEmployeeIdForUser(auth.user);
});

