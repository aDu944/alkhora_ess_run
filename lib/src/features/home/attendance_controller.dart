import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/device/device_services.dart';
import '../../core/network/providers.dart';
import '../../core/offline/offline_queue.dart';
import '../../features/auth/auth_controller.dart';
import 'attendance_repository.dart';

class AttendanceViewState {
  AttendanceViewState({
    required this.employeeId,
    required this.lastLogType,
    required this.lastTimeIso,
    required this.pendingCount,
    required this.syncing,
  });

  final String? employeeId;
  final String? lastLogType; // IN/OUT
  final String? lastTimeIso;
  final int pendingCount;
  final bool syncing;

  AttendanceViewState copyWith({
    String? employeeId,
    String? lastLogType,
    String? lastTimeIso,
    int? pendingCount,
    bool? syncing,
  }) {
    return AttendanceViewState(
      employeeId: employeeId ?? this.employeeId,
      lastLogType: lastLogType ?? this.lastLogType,
      lastTimeIso: lastTimeIso ?? this.lastTimeIso,
      pendingCount: pendingCount ?? this.pendingCount,
      syncing: syncing ?? this.syncing,
    );
  }

  static AttendanceViewState initial() => AttendanceViewState(
        employeeId: null,
        lastLogType: null,
        lastTimeIso: null,
        pendingCount: OfflineQueue.loadAttendance().length,
        syncing: false,
      );
}

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, AttendanceViewState>(AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceViewState> {
  @override
  Future<AttendanceViewState> build() async {
    final s = AttendanceViewState.initial();
    await _refresh(s);
    return state.value ?? s;
  }

  Future<void> _refresh(AttendanceViewState base) async {
    final client = await ref.read(frappeClientProvider.future);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      state = AsyncValue.data(base);
      return;
    }
    final repo = AttendanceRepository(client);
    final emp = await repo.getEmployeeIdForUser(user);
    final last = await repo.getLastCheckin(emp);
    state = AsyncValue.data(
      base.copyWith(
        employeeId: emp,
        lastLogType: last?['log_type'] as String?,
        lastTimeIso: last?['time'] as String?,
        pendingCount: OfflineQueue.loadAttendance().length,
        syncing: false,
      ),
    );
  }

  Future<void> syncPending() async {
    final current = state.value ?? AttendanceViewState.initial();
    state = AsyncValue.data(current.copyWith(syncing: true));

    final hasNet = await DeviceServices.hasNetwork();
    if (!hasNet) {
      state = AsyncValue.data(current.copyWith(syncing: false, pendingCount: OfflineQueue.loadAttendance().length));
      return;
    }

    final client = await ref.read(frappeClientProvider.future);
    final repo = AttendanceRepository(client);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      state = AsyncValue.data(current.copyWith(syncing: false));
      return;
    }
    final emp = current.employeeId ?? await repo.getEmployeeIdForUser(user);

    final items = OfflineQueue.loadAttendance().toList(growable: true);
    final remaining = <Map<String, dynamic>>[];
    for (final it in items) {
      try {
        await repo.createCheckin(
          employeeId: emp,
          logType: (it['logType'] as String?) ?? 'IN',
          time: DateTime.parse(it['time'] as String),
          latitude: (it['latitude'] as num?)?.toDouble(),
          longitude: (it['longitude'] as num?)?.toDouble(),
          accuracy: (it['accuracy'] as num?)?.toDouble(),
        );
      } catch (_) {
        remaining.add(it);
      }
    }
    await OfflineQueue.replaceAttendance(remaining);
    await _refresh(current.copyWith(employeeId: emp, syncing: false));
  }

  Future<void> mark({required String logType}) async {
    final current = state.value ?? AttendanceViewState.initial();
    state = const AsyncValue.loading();

    // Make sure queued actions are attempted first.
    await syncPending();

    final perm = await DeviceServices.ensureLocationPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      state = AsyncValue.data(current.copyWith(pendingCount: OfflineQueue.loadAttendance().length));
      throw StateError('location_permission_required');
    }

    final pos = await DeviceServices.getPosition();
    final hasNet = await DeviceServices.hasNetwork();

    final action = <String, dynamic>{
      'logType': logType,
      'time': DateTime.now().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
    };

    if (!hasNet) {
      await OfflineQueue.enqueueAttendance(action);
      await _refresh(current);
      return;
    }

    final client = await ref.read(frappeClientProvider.future);
    final repo = AttendanceRepository(client);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      state = AsyncValue.data(current);
      return;
    }
    final emp = current.employeeId ?? await repo.getEmployeeIdForUser(user);
    await repo.createCheckin(
      employeeId: emp,
      logType: logType,
      time: DateTime.now(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
    );
    await _refresh(current.copyWith(employeeId: emp));
  }
}

