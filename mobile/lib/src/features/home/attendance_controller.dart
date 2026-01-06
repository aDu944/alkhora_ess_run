<<<<<<< Current (Your changes)
=======
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/device/device_id.dart';
import '../../core/device/device_services.dart';
import '../../core/device/geofence.dart';
import '../../core/network/providers.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/storage/secure_kv.dart';
import '../../core/time/providers.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/biometric_service.dart';
import 'attendance_repository.dart';
import 'attendance_models.dart';

class AttendanceViewState {
  AttendanceViewState({
    required this.employeeId,
    required this.employeeName,
    required this.lastLogType,
    required this.lastTimeIso,
    required this.pendingCount,
    required this.syncing,
    required this.geofenceEnabled,
    required this.withinGeofence,
    required this.mockLocationDetected,
    required this.distanceMeters,
    required this.geofenceError,
    required this.ntpSynchronized,
    required this.analytics,
    required this.recent,
  });

  final String? employeeId;
  final String? employeeName;
  final String? lastLogType; // IN/OUT
  final String? lastTimeIso;
  final int pendingCount;
  final bool syncing;
  final bool geofenceEnabled;
  final bool withinGeofence;
  final bool mockLocationDetected;
  final double? distanceMeters;
  final String? geofenceError;
  final bool ntpSynchronized;
  final AttendanceAnalytics analytics;
  final List<CheckinEvent> recent;

  String get nextLogType => (lastLogType == 'IN') ? 'OUT' : 'IN';

  bool get locked {
    if (mockLocationDetected) return true;
    if (!geofenceEnabled) return false;
    // Let the user tap to grant permission; enforcement happens in `mark()`.
    if (geofenceError == 'location_permission_denied') return false;
    if (geofenceError != null) return true;
    return !withinGeofence;
  }

  AttendanceViewState copyWith({
    String? employeeId,
    String? employeeName,
    String? lastLogType,
    String? lastTimeIso,
    int? pendingCount,
    bool? syncing,
    bool? geofenceEnabled,
    bool? withinGeofence,
    bool? mockLocationDetected,
    double? distanceMeters,
    String? geofenceError,
    bool? ntpSynchronized,
    AttendanceAnalytics? analytics,
    List<CheckinEvent>? recent,
  }) {
    return AttendanceViewState(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      lastLogType: lastLogType ?? this.lastLogType,
      lastTimeIso: lastTimeIso ?? this.lastTimeIso,
      pendingCount: pendingCount ?? this.pendingCount,
      syncing: syncing ?? this.syncing,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      withinGeofence: withinGeofence ?? this.withinGeofence,
      mockLocationDetected: mockLocationDetected ?? this.mockLocationDetected,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      geofenceError: geofenceError ?? this.geofenceError,
      ntpSynchronized: ntpSynchronized ?? this.ntpSynchronized,
      analytics: analytics ?? this.analytics,
      recent: recent ?? this.recent,
    );
  }

  static AttendanceViewState initial() => AttendanceViewState(
        employeeId: null,
        employeeName: null,
        lastLogType: null,
        lastTimeIso: null,
        pendingCount: 0,
        syncing: false,
        geofenceEnabled: AppConfig.geofenceEnabled,
        withinGeofence: !AppConfig.geofenceEnabled,
        mockLocationDetected: false,
        distanceMeters: null,
        geofenceError: null,
        ntpSynchronized: false,
        analytics: const AttendanceAnalytics(
          todayWorked: Duration.zero,
          weekWorked: Duration.zero,
          todayGoal: Duration(hours: 8),
          weekGoal: Duration(hours: 40),
        ),
        recent: const [],
      );
}

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, AttendanceViewState>(AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceViewState> {
  static const _uuid = Uuid();

  @override
  Future<AttendanceViewState> build() async {
    final s = AttendanceViewState.initial();

    // Keep geofence status flowing into state (bi-directional: server + device signals).
    ref.listen<AsyncValue<GeofenceStatus>>(geofenceStatusProvider, (prev, next) {
      final current = state.valueOrNull ?? s;
      final data = next.valueOrNull;
      if (data == null) return;
      state = AsyncValue.data(
        current.copyWith(
          geofenceEnabled: data.enabled,
          withinGeofence: data.within,
          mockLocationDetected: data.mockLocationDetected,
          distanceMeters: data.distanceMeters,
          geofenceError: data.error,
        ),
      );
    });

    Timer? pollTimer;
    pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final current = state.valueOrNull ?? s;
      try {
        await _refresh(current, preferSilent: true);
      } catch (_) {
        // ignore transient errors while polling
      }
    });
    ref.onDispose(() => pollTimer?.cancel());

    await _refresh(s);
    return state.value ?? s;
  }

  Future<void> _refresh(AttendanceViewState base, {bool preferSilent = false}) async {
    final client = await ref.read(frappeClientProvider.future);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      state = AsyncValue.data(base);
      return;
    }
    final repo = AttendanceRepository(client);
    final empRow = await repo.getEmployeeForUser(user);
    final emp = empRow['name'] as String;
    final empName = empRow['employee_name'] as String?;
    final last = await repo.getLastCheckin(emp);
    final pending = await OfflineQueue.countAttendance();
    final timeSvc = await ref.read(timeSyncServiceProvider.future);
    try {
      await timeSvc.sync();
    } catch (_) {
      // keep cached offset
    }
    final nowLocal = timeSvc.nowUtc().toLocal();

    final weekStartLocal = _startOfWeekLocal(nowLocal);
    final fetchStart = weekStartLocal.subtract(const Duration(days: 1));
    final raw = await repo.getCheckins(
      employeeId: emp,
      from: fetchStart.toUtc(),
      to: timeSvc.nowUtc(),
      limit: 200,
      asc: true,
    );
    final events = raw
        .map((m) => CheckinEvent(
              id: (m['name'] as String?) ?? '',
              logType: (m['log_type'] as String?) ?? '',
              time: DateTime.tryParse((m['time'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
            ))
        .where((e) => e.id.isNotEmpty && (e.logType == 'IN' || e.logType == 'OUT'))
        .toList(growable: false);

    final todayStartLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayWorked = _workedWithinRangeLocal(events, start: todayStartLocal, end: nowLocal, includeOpen: true);
    final weekWorked = _workedWithinRangeLocal(events, start: weekStartLocal, end: nowLocal, includeOpen: true);
    final analytics = AttendanceAnalytics(
      todayWorked: todayWorked,
      weekWorked: weekWorked,
      todayGoal: const Duration(hours: 8),
      weekGoal: const Duration(hours: 40),
    );

    final recent = events.length <= 12
        ? events.reversed.toList(growable: false)
        : events.sublist(events.length - 12).reversed.toList(growable: false);
    state = AsyncValue.data(
      base.copyWith(
        employeeId: emp,
        employeeName: empName,
        lastLogType: last?['log_type'] as String?,
        lastTimeIso: last?['time'] as String?,
        pendingCount: pending,
        syncing: preferSilent ? base.syncing : false,
        ntpSynchronized: timeSvc.hasTrustedOffset,
        analytics: analytics,
        recent: recent,
      ),
    );
  }

  Future<void> syncPending() async {
    final current = state.value ?? AttendanceViewState.initial();
    state = AsyncValue.data(current.copyWith(syncing: true));

    final hasNet = await DeviceServices.hasNetwork();
    if (!hasNet) {
      state = AsyncValue.data(current.copyWith(syncing: false, pendingCount: await OfflineQueue.countAttendance()));
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

    final items = (await OfflineQueue.loadAttendance()).toList(growable: true);
    final failed = <Map<String, dynamic>>[];
    final succeededIds = <String>[];
    final deviceId = await DeviceId.getOrCreate();
    for (final it in items) {
      try {
        final id = it['id'] as String?;
        await repo.createCheckin(
          employeeId: emp,
          logType: (it['logType'] as String?) ?? 'IN',
          time: DateTime.parse(it['time'] as String),
          deviceId: deviceId,
          idempotencyKey: id,
          latitude: (it['latitude'] as num?)?.toDouble(),
          longitude: (it['longitude'] as num?)?.toDouble(),
          accuracy: (it['accuracy'] as num?)?.toDouble(),
        );
        if (id != null && id.isNotEmpty) succeededIds.add(id);
      } catch (_) {
        failed.add(it);
      }
    }
    // Fast-path delete succeeded, then rewrite only failures (keeps ordering stable).
    await OfflineQueue.deleteAttendanceByIds(succeededIds);
    if (failed.isNotEmpty) {
      await OfflineQueue.replaceAttendance(failed);
    }
    await _refresh(current.copyWith(employeeId: emp, syncing: false));
  }

  Future<void> mark({required String logType}) async {
    final current = state.value ?? AttendanceViewState.initial();
    state = AsyncValue.data(current.copyWith(syncing: false));

    // Make sure queued actions are attempted first.
    await syncPending();

    final latest = state.valueOrNull ?? current;
    if (latest.locked) {
      if (latest.mockLocationDetected) {
        throw StateError('mock_location_detected');
      }
      throw StateError(latest.geofenceError ?? 'geofence_locked');
    }

    final perm = await DeviceServices.ensureLocationPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      state = AsyncValue.data(current.copyWith(pendingCount: await OfflineQueue.countAttendance()));
      throw StateError('location_permission_required');
    }

    final pos = await DeviceServices.getPosition();
    if (pos.isMocked) {
      throw StateError('mock_location_detected');
    }
    if (AppConfig.geofenceEnabled) {
      final dist = Geolocator.distanceBetween(
        AppConfig.officeLatitude,
        AppConfig.officeLongitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist > AppConfig.officeRadiusMeters) {
        throw StateError('geofence_locked');
      }
    }
    final hasNet = await DeviceServices.hasNetwork();

    final deviceId = await DeviceId.getOrCreate();
    final timeSvc = await ref.read(timeSyncServiceProvider.future);
    try {
      await timeSvc.sync();
    } catch (_) {
      // Keep last cached offset; we'll still use it if present.
    }

    // Optional biometric prompt for punch action (uses same setting as app unlock).
    final biometricRequired = (await SecureKv.read(SecureKeys.biometricEnabled)) == '1';
    if (biometricRequired) {
      final ok = await BiometricService.authenticate(
        reason: 'Confirm ${logType == 'IN' ? 'check-in' : 'check-out'}',
      );
      if (!ok) {
        throw StateError('biometric_failed');
      }
    }

    final nowUtc = timeSvc.nowUtc();
    final id = _uuid.v4();
    final action = <String, dynamic>{
      'id': id,
      'logType': logType,
      'time': nowUtc.toIso8601String(),
      'deviceId': deviceId,
      'ntpLastSyncUtc': timeSvc.lastSyncUtc?.toIso8601String(),
      'ntpSynchronized': timeSvc.hasTrustedOffset,
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

    // Server-side de-duplication guard: if the last server log already matches the request
    // and is recent, treat this as already completed (prevents double taps / multi-device races).
    final last = await repo.getLastCheckin(emp);
    final lastType = last?['log_type'] as String?;
    final lastTimeRaw = last?['time'] as String?;
    final lastTime = lastTimeRaw != null ? DateTime.tryParse(lastTimeRaw) : null;
    if (lastType == logType && lastTime != null) {
      final age = nowUtc.difference(lastTime.toUtc()).abs();
      if (age < const Duration(minutes: 2)) {
        await _refresh(current.copyWith(employeeId: emp));
        return;
      }
    }

    await repo.createCheckin(
      employeeId: emp,
      logType: logType,
      time: nowUtc,
      deviceId: deviceId,
      idempotencyKey: id,
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
    );
    await _refresh(current.copyWith(employeeId: emp));
  }
}

DateTime _startOfWeekLocal(DateTime d) {
  // Monday = 1 ... Sunday = 7
  final daysFromMonday = d.weekday - DateTime.monday;
  final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: daysFromMonday));
  return start;
}

Duration _workedWithinRangeLocal(
  List<CheckinEvent> events, {
  required DateTime start,
  required DateTime end,
  required bool includeOpen,
}) {
  if (end.isBefore(start)) return Duration.zero;
  if (events.isEmpty) return Duration.zero;

  // Ensure chronological.
  final sorted = events.toList(growable: false)..sort((a, b) => a.time.compareTo(b.time));

  String? lastTypeBefore;
  DateTime? lastTimeBefore;
  for (final e in sorted) {
    final t = e.time.toLocal();
    if (t.isBefore(start)) {
      lastTypeBefore = e.logType;
      lastTimeBefore = t;
      continue;
    }
    break;
  }

  DateTime? openIn;
  if (lastTypeBefore == 'IN' && lastTimeBefore != null) {
    openIn = start;
  }

  var totalMs = 0;
  for (final e in sorted) {
    final t = e.time.toLocal();
    if (t.isBefore(start)) continue;
    if (t.isAfter(end)) break;

    if (e.logType == 'IN') {
      openIn = t;
    } else if (e.logType == 'OUT') {
      if (openIn != null) {
        totalMs += t.difference(openIn).inMilliseconds;
      }
      openIn = null;
    }
  }

  if (includeOpen && openIn != null) {
    totalMs += end.difference(openIn).inMilliseconds;
  }

  if (totalMs < 0) totalMs = 0;
  return Duration(milliseconds: totalMs);
}

>>>>>>> Incoming (Background Agent changes)
