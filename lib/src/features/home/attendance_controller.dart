import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config/app_config.dart' show AppConfig, AllowedLocation;
import '../../core/device/device_services.dart';
import '../../core/network/frappe_client.dart';
import '../../core/network/providers.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/time/providers.dart';
import '../../core/time/time_sync_service.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/attendance/attendance_page.dart';
import '../../l10n/app_texts.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';

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
    this.officeLocationName,
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
  final String? officeLocationName;

  String get nextLogType => (lastLogType == 'IN') ? 'OUT' : 'IN';

  bool get locked {
    if (mockLocationDetected) return true;
    if (!geofenceEnabled) return false;
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
    String? officeLocationName,
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
      officeLocationName: officeLocationName ?? this.officeLocationName,
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
        officeLocationName: null,
      );
}

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, AttendanceViewState>(AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceViewState> {
  Timer? _pollTimer;

  @override
  Future<AttendanceViewState> build() async {
    final s = AttendanceViewState.initial();

    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final current = state.valueOrNull ?? s;
      try {
        await _refresh(current, preferSilent: true);
      } catch (_) {
        // ignore transient errors while polling
      }
    });
    ref.onDispose(() => _pollTimer?.cancel());

    final initialState = await _refresh(s);
    return state.value ?? initialState;
  }

  Future<AttendanceViewState> _refresh(AttendanceViewState base, {bool preferSilent = false}) async {
    final client = await ref.read(frappeClientProvider.future);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      state = AsyncValue.data(base);
      return base;
    }
    final repo = AttendanceRepository(client);
    // Check if app language is English to prefer English name
    final locale = ref.read(appLocaleProvider);
    final preferEnglish = locale?.languageCode == 'en';
    final empRow = await repo.getEmployeeForUser(user, preferEnglish: preferEnglish);
    final emp = empRow['name'] as String;
    
    // Prefer English name if available and app language is English
    String? empName;
    if (preferEnglish) {
      empName = empRow['employee_name_in_english'] as String? ??
                empRow['first_name'] as String? ??
                empRow['employee_name'] as String?;
    } else {
      empName = empRow['employee_name'] as String?;
    }
    final last = await repo.getLastCheckin(emp);
    final pending = await OfflineQueue.countAttendance();
    
    // Fetch office location name (non-blocking, cache result)
    // Don't block on this - fetch in background
    String? officeLocation = base.officeLocationName; // Use cached value
    repo.getOfficeLocationName(emp).then((location) {
      // Update state with new location if different (non-blocking)
      final currentState = state.valueOrNull;
      if (currentState != null && location != currentState.officeLocationName) {
        state = AsyncValue.data(currentState.copyWith(officeLocationName: location));
      }
    }).catchError((e) {
      debugPrint('Failed to fetch office location: $e');
    });
    final timeSvc = ref.read(timeSyncServiceProvider).valueOrNull;
    final nowLocal = timeSvc != null ? timeSvc.nowUtc().toLocal() : DateTime.now().toLocal();

    // Calculate analytics
    final weekStartLocal = _startOfWeekLocal(nowLocal);
    final fetchStart = weekStartLocal.subtract(const Duration(days: 1));
    // Add a small buffer to the end time to ensure we get the just-created check-in
    // Use local time for both since check-ins are stored in local time format
    final fetchEnd = nowLocal.add(const Duration(minutes: 1));
    List<CheckinEvent> events = [];
    if (timeSvc != null) {
      try {
        final raw = await repo.getCheckins(
          employeeId: emp,
          from: fetchStart, // Already local time
          to: fetchEnd,     // Already local time
          limit: 200,
          asc: true,
        );
        // Map raw check-ins to CheckinEvent objects
        // Check for late entry (IN) and early exit (OUT) - use ERPNext fields if available
        final tempEvents = <CheckinEvent>[];
        
        // Cache shift times per date to avoid repeated API calls
        final shiftTimesCache = <String, ({TimeOfDay start, TimeOfDay end})?>{};
        
        Future<({TimeOfDay start, TimeOfDay end})?> getShiftTimesForDate(DateTime eventDate) async {
          final dateKey = '${eventDate.year}-${eventDate.month}-${eventDate.day}';
          if (!shiftTimesCache.containsKey(dateKey)) {
            shiftTimesCache[dateKey] = await getEmployeeShiftTimes(emp, eventDate);
          }
          return shiftTimesCache[dateKey];
        }
        
        for (final m in raw) {
          final id = (m['name'] as String?) ?? '';
          final logType = (m['log_type'] as String?) ?? '';
          final timeStr = (m['time'] as String?) ?? '';
          
          if (id.isEmpty || (logType != 'IN' && logType != 'OUT')) continue;
          
          final time = DateTime.tryParse(timeStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (time == DateTime.fromMillisecondsSinceEpoch(0)) continue;
          
          final eventLocal = time.toLocal();
          final eventDate = DateTime(eventLocal.year, eventLocal.month, eventLocal.day);
          
          // Check late entry (for IN events) or early exit (for OUT events)
          bool isLateEntry = false;
          bool isEarlyExit = false;
          
          // Calculate late entry / early exit client-side using shift times
          // (ERPNext fields may not be available or permitted in queries)
          final shiftTimes = await getShiftTimesForDate(eventDate);
          
          if (logType == 'IN' && shiftTimes != null) {
            final checkInTimeOfDay = TimeOfDay.fromDateTime(eventLocal);
            final checkInMinutes = checkInTimeOfDay.hour * 60 + checkInTimeOfDay.minute;
            final shiftStartMinutes = shiftTimes.start.hour * 60 + shiftTimes.start.minute;
            // Late if check-in is more than 15 minutes after shift start
            isLateEntry = checkInMinutes > (shiftStartMinutes + 15);
          } else if (logType == 'OUT' && shiftTimes != null) {
            final checkOutTimeOfDay = TimeOfDay.fromDateTime(eventLocal);
            final checkOutMinutes = checkOutTimeOfDay.hour * 60 + checkOutTimeOfDay.minute;
            final shiftEndMinutes = shiftTimes.end.hour * 60 + shiftTimes.end.minute;
            // Early if check-out is more than 15 minutes before shift end
            isEarlyExit = checkOutMinutes < (shiftEndMinutes - 15);
          }
          
          tempEvents.add(CheckinEvent(
            id: id,
            logType: logType,
            time: time,
            isLateEntry: isLateEntry,
            isEarlyExit: isEarlyExit,
          ));
        }
        
        events = tempEvents.toList(growable: false);
        
        debugPrint('Fetched ${events.length} check-in events for analytics calculation');
      } catch (e) {
        debugPrint('Error fetching check-ins for analytics: $e');
        // Ignore errors fetching check-ins, continue with empty list
      }
    }

    final todayStartLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayWorked = _workedWithinRangeLocal(events, start: todayStartLocal, end: nowLocal, includeOpen: true);
    final weekWorked = _workedWithinRangeLocal(events, start: weekStartLocal, end: nowLocal, includeOpen: true);
    final analytics = AttendanceAnalytics(
      todayWorked: todayWorked,
      weekWorked: weekWorked,
      todayGoal: const Duration(hours: 8),
      weekGoal: const Duration(hours: 40),
    );

    // Get most recent 12 events (sorted descending by time, most recent first)
    final recent = events.length <= 12
        ? List<CheckinEvent>.from(events.reversed)
        : List<CheckinEvent>.from(events.sublist(events.length - 12).reversed);
    
    debugPrint('Recent activity: ${recent.length} events (total: ${events.length})');
    if (recent.isNotEmpty) {
      debugPrint('Most recent: ${recent.first.logType} at ${recent.first.time}');
    }

    // Check geofence status against allowed locations
    bool withinGeofence = false;
    bool mockLocationDetected = false;
    double? distanceMeters;
    String? geofenceError;
    String? nearestLocationName;
    
    // Fetch allowed check-in locations for this employee
    List<AllowedLocation> allowedLocations = [];
    try {
      final allowedLocationsData = await repo.getAllowedCheckinLocations(emp);
      allowedLocations = allowedLocationsData
          .map((loc) => AllowedLocation.fromMap(loc))
          .where((loc) => loc.latitude.abs() > 0.000001 && loc.longitude.abs() > 0.000001)
          .toList();
    } catch (e) {
      debugPrint('Error fetching allowed locations: $e');
    }
    
    // If no custom locations, use default office location if configured
    if (allowedLocations.isEmpty && AppConfig.geofenceEnabled) {
      allowedLocations = [
        AllowedLocation(
          name: 'Office',
          latitude: AppConfig.officeLatitude,
          longitude: AppConfig.officeLongitude,
          radiusMeters: AppConfig.officeRadiusMeters,
        ),
      ];
    }
    
    final geofenceEnabled = allowedLocations.isNotEmpty;
    
    if (geofenceEnabled) {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          geofenceError = 'location_permission_denied';
        } else {
          final pos = await DeviceServices.getPosition();
          mockLocationDetected = pos.isMocked;
          
          // Check if position is within any allowed location
          double? minDistance;
          AllowedLocation? nearestLocation;
          
          for (final location in allowedLocations) {
            final dist = Geolocator.distanceBetween(
              location.latitude,
              location.longitude,
              pos.latitude,
              pos.longitude,
            );
            
            if (dist <= location.radiusMeters) {
              withinGeofence = true;
              nearestLocationName = location.name;
              distanceMeters = dist;
              break; // Found a valid location
            }
            
            // Track nearest location for error messages
            if (minDistance == null || dist < minDistance) {
              minDistance = dist;
              nearestLocation = location;
            }
          }
          
          // If not within any location, set distance to nearest
          if (!withinGeofence && nearestLocation != null) {
            distanceMeters = minDistance;
            nearestLocationName = nearestLocation.name;
          }
        }
      } catch (_) {
        geofenceError = 'location_services_disabled';
      }
    } else {
      // No geofencing configured, allow check-in from anywhere
      withinGeofence = true;
    }

    final updatedState = base.copyWith(
      employeeId: emp,
      employeeName: empName,
      lastLogType: last?['log_type'] as String?,
      lastTimeIso: last?['time'] as String?,
      pendingCount: pending,
      // Preserve syncing state from base if preferSilent is true, otherwise use base.syncing (which may be true during check-in refresh)
      syncing: preferSilent ? base.syncing : base.syncing,
      geofenceEnabled: geofenceEnabled,
      ntpSynchronized: timeSvc?.hasTrustedOffset ?? false,
      analytics: analytics,
      recent: recent,
      withinGeofence: withinGeofence,
      mockLocationDetected: mockLocationDetected,
      distanceMeters: distanceMeters,
      geofenceError: geofenceError,
      officeLocationName: nearestLocationName ?? officeLocation,
    );
    
    state = AsyncValue.data(updatedState);
    return updatedState;
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

    final items = OfflineQueue.loadAttendance().toList(growable: true);
    final failed = <Map<String, dynamic>>[];
    final succeededIds = <String>[];
    for (final it in items) {
      try {
        final id = it['id'] as String?;
        await repo.createCheckin(
          employeeId: emp,
          logType: (it['logType'] as String?) ?? 'IN',
          time: DateTime.parse(it['time'] as String),
          latitude: (it['latitude'] as num?)?.toDouble(),
          longitude: (it['longitude'] as num?)?.toDouble(),
          accuracy: (it['accuracy'] as num?)?.toDouble(),
        );
        if (id != null && id.isNotEmpty) succeededIds.add(id);
      } catch (_) {
        failed.add(it);
      }
    }
    await OfflineQueue.deleteAttendanceByIds(succeededIds);
    if (failed.isNotEmpty) {
      await OfflineQueue.replaceAttendance(failed);
    }
    await _refresh(current.copyWith(employeeId: emp, syncing: false));
  }

  /// Get employee's shift times for a specific date
  /// Returns start and end times, or null if not configured
  /// Priority: 1. Shift Assignment for date, 2. Default shift from Employee, 3. Default (9 AM - 5 PM)
  Future<({TimeOfDay start, TimeOfDay end})?> getEmployeeShiftTimes(String employeeId, DateTime forDate) async {
    try {
      final client = await ref.read(frappeClientProvider.future);
      final repo = AttendanceRepository(client);
      
      // First, try to get active Shift Assignment for this date
      // Shift Assignment is date-specific and overrides default shift
      final dateStr = forDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
      try {
        final shiftAssignmentRes = await client.dio.get(
          '/api/resource/Shift Assignment',
          queryParameters: {
            'fields': jsonEncode(['shift_type', 'start_date', 'end_date']),
            'filters': jsonEncode([
              ['employee', '=', employeeId],
              ['start_date', '<=', dateStr],
              ['status', '=', 'Active'],
            ]),
            'order_by': 'start_date desc',
            'limit_page_length': 1,
          },
        );
        final shiftAssignments = (shiftAssignmentRes.data is Map) 
            ? (shiftAssignmentRes.data['data'] as List?) 
            : null;
        if (shiftAssignments != null && shiftAssignments.isNotEmpty) {
          final assignment = shiftAssignments.first as Map;
          final endDateStr = assignment['end_date'] as String?;
          // Check if assignment is valid for this date
          // endDate is null for ongoing assignments, or we compare date strings (YYYY-MM-DD format)
          bool isValid = false;
          if (endDateStr == null || endDateStr.isEmpty) {
            isValid = true; // Ongoing assignment
          } else {
            // Compare date strings (YYYY-MM-DD format allows string comparison)
            isValid = endDateStr.compareTo(dateStr) >= 0;
          }
          
          if (isValid) {
            final shiftTypeFromAssignment = assignment['shift_type'] as String?;
            if (shiftTypeFromAssignment != null && shiftTypeFromAssignment.isNotEmpty) {
              final times = await _getShiftTimesFromType(client, shiftTypeFromAssignment);
              if (times != null) {
                debugPrint('Using Shift Assignment shift: $shiftTypeFromAssignment for date $dateStr');
                return times;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Could not fetch Shift Assignment: $e');
        // Continue to try default shift
      }
      
      // Fallback: Try to get default shift from Employee record
      final empData = await repo.getEmployee(employeeId);
      final shiftType = empData['default_shift'] as String? ?? 
                       empData['shift'] as String? ?? 
                       empData['shift_type'] as String?;
      
      if (shiftType != null && shiftType.isNotEmpty) {
        final times = await _getShiftTimesFromType(client, shiftType);
        if (times != null) {
          debugPrint('Using default shift from Employee: $shiftType');
          return times;
        }
      }
      
      // Default shift times based on day of week if no shift configured
      final dayOfWeek = forDate.weekday; // 1=Monday, 7=Sunday
      TimeOfDay startTime;
      TimeOfDay endTime;
      
      final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dayName = dayNames[dayOfWeek];
      
      if (dayOfWeek == DateTime.saturday) {
        // Saturday: 9 AM - 3 PM
        startTime = const TimeOfDay(hour: 9, minute: 0);
        endTime = const TimeOfDay(hour: 15, minute: 0);
        debugPrint('No shift configured, using default for Saturday: 09:00 - 15:00');
      } else {
        // Sunday to Thursday (and Friday): 9 AM - 4 PM
        startTime = const TimeOfDay(hour: 9, minute: 0);
        endTime = const TimeOfDay(hour: 16, minute: 0);
        debugPrint('No shift configured, using default for $dayName: 09:00 - 16:00');
      }
      
      return (start: startTime, end: endTime);
    } catch (e) {
      debugPrint('Error fetching shift times: $e');
      // Default based on day of week
      final dayOfWeek = forDate.weekday;
      if (dayOfWeek == DateTime.saturday) {
        return (start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 15, minute: 0));
      } else {
        return (start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 16, minute: 0));
      }
    }
  }

  /// Helper to fetch start and end times from Shift Type
  Future<({TimeOfDay start, TimeOfDay end})?> _getShiftTimesFromType(FrappeClient client, String shiftType) async {
    try {
      final shiftRes = await client.dio.get(
        '/api/resource/Shift Type/$shiftType',
        queryParameters: {'fields': jsonEncode(['start_time', 'end_time'])},
      );
      final shiftData = shiftRes.data is Map ? shiftRes.data['data'] : null;
      if (shiftData is Map) {
        final startTimeStr = shiftData['start_time'] as String?;
        final endTimeStr = shiftData['end_time'] as String?;
        
        TimeOfDay? startTime;
        TimeOfDay? endTime;
        
        if (startTimeStr != null && startTimeStr.isNotEmpty) {
          final timeParts = startTimeStr.split(':');
          if (timeParts.length >= 2) {
            final hour = int.tryParse(timeParts[0]) ?? 9;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            startTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
        
        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          final timeParts = endTimeStr.split(':');
          if (timeParts.length >= 2) {
            final hour = int.tryParse(timeParts[0]) ?? 17;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            endTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
        
        if (startTime != null && endTime != null) {
          return (start: startTime, end: endTime);
        }
      }
    } catch (e) {
      debugPrint('Error fetching Shift Type $shiftType: $e');
    }
    return null;
  }

  /// Get employee's default shift start time (backward compatibility)
  /// Returns the shift start time as a TimeOfDay, or null if not configured
  Future<TimeOfDay?> getEmployeeShiftStartTime(String employeeId) async {
    final times = await getEmployeeShiftTimes(employeeId, DateTime.now());
    return times?.start;
  }

  /// Check if a check-in time is late (after shift start time)
  Future<bool> isLateEntryInternal(String employeeId, DateTime checkInTime) async {
    try {
      final checkInLocal = checkInTime.toLocal();
      final shiftTimes = await getEmployeeShiftTimes(employeeId, checkInLocal);
      if (shiftTimes == null) return false;
      
      final checkInTimeOfDay = TimeOfDay.fromDateTime(checkInLocal);
      
      // Compare times
      final checkInMinutes = checkInTimeOfDay.hour * 60 + checkInTimeOfDay.minute;
      final shiftStartMinutes = shiftTimes.start.hour * 60 + shiftTimes.start.minute;
      
      // Late if check-in is more than 15 minutes after shift start
      // (15-minute grace period to account for minor delays)
      final isLate = checkInMinutes > (shiftStartMinutes + 15);
      if (isLate) {
        debugPrint('Late entry detected: Check-in at ${checkInTimeOfDay.hour}:${checkInTimeOfDay.minute}, Shift starts at ${shiftTimes.start.hour}:${shiftTimes.start.minute}');
      }
      return isLate;
    } catch (e) {
      debugPrint('Error checking late entry: $e');
      return false;
    }
  }

  /// Check if a check-out time is early (before shift end time)
  Future<bool> isEarlyExitInternal(String employeeId, DateTime checkOutTime) async {
    try {
      final checkOutLocal = checkOutTime.toLocal();
      final shiftTimes = await getEmployeeShiftTimes(employeeId, checkOutLocal);
      if (shiftTimes == null) return false;
      
      final checkOutTimeOfDay = TimeOfDay.fromDateTime(checkOutLocal);
      
      // Compare times
      final checkOutMinutes = checkOutTimeOfDay.hour * 60 + checkOutTimeOfDay.minute;
      final shiftEndMinutes = shiftTimes.end.hour * 60 + shiftTimes.end.minute;
      
      // Early exit if check-out is more than 15 minutes before shift end
      // (15-minute grace period before official end time)
      final isEarly = checkOutMinutes < (shiftEndMinutes - 15);
      if (isEarly) {
        debugPrint('Early exit detected: Check-out at ${checkOutTimeOfDay.hour}:${checkOutTimeOfDay.minute}, Shift ends at ${shiftTimes.end.hour}:${shiftTimes.end.minute}');
      }
      return isEarly;
    } catch (e) {
      debugPrint('Error checking early exit: $e');
      return false;
    }
  }

  Future<void> mark({required String logType}) async {
    final current = state.value ?? AttendanceViewState.initial();
    state = AsyncValue.data(current.copyWith(syncing: true));

    // Sync pending items in background (non-blocking) - don't wait for it
    syncPending().catchError((e) {
      debugPrint('Background sync failed: $e');
    });

    // Use current state (don't wait for sync to complete)
    final latest = current;
    if (latest.locked) {
      if (latest.mockLocationDetected) {
        throw StateError('mock_location_detected');
      }
      throw StateError(latest.geofenceError ?? 'geofence_locked');
    }

    LocationPermission perm;
    try {
      perm = await DeviceServices.ensureLocationPermission();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(pendingCount: await OfflineQueue.countAttendance()));
      throw StateError('location_permission_required');
    }
    
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      state = AsyncValue.data(current.copyWith(pendingCount: await OfflineQueue.countAttendance()));
      throw StateError('location_permission_required');
    }

    Position pos;
    try {
      pos = await DeviceServices.getPosition();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(pendingCount: await OfflineQueue.countAttendance()));
      throw StateError('location_permission_required');
    }
    
    if (pos.isMocked) {
      throw StateError('mock_location_detected');
    }
    
    // Check geofencing against allowed locations for this employee
    final client = await ref.read(frappeClientProvider.future);
    final repo = AttendanceRepository(client);
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) {
      throw StateError('user_not_authenticated');
    }
    final emp = current.employeeId ?? await repo.getEmployeeIdForUser(user);
    
    // Fetch allowed locations
    List<AllowedLocation> allowedLocations = [];
    try {
      final allowedLocationsData = await repo.getAllowedCheckinLocations(emp);
      allowedLocations = allowedLocationsData
          .map((loc) => AllowedLocation.fromMap(loc))
          .where((loc) => loc.latitude.abs() > 0.000001 && loc.longitude.abs() > 0.000001)
          .toList();
    } catch (e) {
      debugPrint('Error fetching allowed locations during check-in: $e');
    }
    
    // If no custom locations, use default office location if configured
    if (allowedLocations.isEmpty && AppConfig.geofenceEnabled) {
      allowedLocations = [
        AllowedLocation(
          name: 'Office',
          latitude: AppConfig.officeLatitude,
          longitude: AppConfig.officeLongitude,
          radiusMeters: AppConfig.officeRadiusMeters,
        ),
      ];
    }
    
    // Check if within any allowed location
    if (allowedLocations.isNotEmpty) {
      bool withinAnyLocation = false;
      for (final location in allowedLocations) {
        final dist = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (dist <= location.radiusMeters) {
          withinAnyLocation = true;
          break;
        }
      }
      if (!withinAnyLocation) {
        throw StateError('geofence_locked');
      }
    }
    bool hasNet;
    try {
      hasNet = await DeviceServices.hasNetwork();
    } catch (_) {
      hasNet = false; // Assume offline on error
    }

    // Get time service - use cached instance if available, otherwise use device time
    // Don't block on time service creation - use device time immediately
    TimeSyncService timeSvc;
    final timeSvcAsync = ref.read(timeSyncServiceProvider);
    if (timeSvcAsync.hasValue && timeSvcAsync.value != null) {
      timeSvc = timeSvcAsync.value!;
    } else {
      // Use device time immediately - don't wait for time service
      timeSvc = TimeSyncService.deviceTimeOnly();
    }
    
    // Don't sync time during check-in - use cached/device time immediately
    // Time sync happens in background via polling

    final nowUtc = timeSvc.nowUtc();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final action = <String, dynamic>{
      'id': id,
      'logType': logType,
      'time': nowUtc.toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
    };

    if (!hasNet) {
      await OfflineQueue.enqueueAttendance(action);
      await _refresh(current);
      return;
    }

    try {
      final client = await ref.read(frappeClientProvider.future);
      final repo = AttendanceRepository(client);
      final user = ref.read(authControllerProvider).valueOrNull?.user;
      if (user == null) {
        state = AsyncValue.data(current);
        throw StateError('user_not_authenticated');
      }
      final emp = current.employeeId ?? await repo.getEmployeeIdForUser(user);

      await repo.createCheckin(
        employeeId: emp,
        logType: logType,
        time: nowUtc,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
      
      debugPrint('Check-in created successfully, refreshing state...');
      
      // Wait for ERPNext to process and index the check-in
      // ERPNext might need a moment to make the record available via API
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Retry getting last check-in a few times if needed (ERPNext indexing delay)
      Map<String, dynamic>? verifiedLast;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          verifiedLast = await repo.getLastCheckin(emp);
          if (verifiedLast != null && verifiedLast['log_type'] == logType) {
            debugPrint('Verified last check-in: ${verifiedLast['log_type']} at ${verifiedLast['time']}');
            break;
          }
        } catch (e) {
          debugPrint('Attempt ${attempt + 1} - Could not verify last check-in: $e');
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      
      // Refresh full state data (this will update analytics, recent activity, etc.)
      // This fetches all check-ins and recalculates analytics
      // Keep syncing: true during refresh so spinner stays visible until button text updates
      final refreshedState = await _refresh(
        AttendanceViewState.initial().copyWith(
          employeeId: emp,
          syncing: true, // Keep syncing true during refresh
        ),
        preferSilent: false, // Not silent - ensure UI updates
      );
      
      // Small delay to ensure UI has rendered the updated button text with new lastLogType
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Now set syncing to false AFTER refresh completes and state has new lastLogType
      final finalState = refreshedState.copyWith(syncing: false);
      
      // Force state update to ensure UI rebuilds immediately with updated button text
      state = AsyncValue.data(finalState);
      
      // Also invalidate attendance records provider so the attendance page updates
      // Note: Attendance records might take longer to process in ERPNext
      ref.invalidate(attendanceRecordsProvider);
      
      debugPrint('✅ State refreshed after check-in');
      debugPrint('   Analytics - Today: ${refreshedState.analytics.todayWorked.inMinutes}min, Week: ${refreshedState.analytics.weekWorked.inMinutes}min');
      debugPrint('   Recent events count: ${refreshedState.recent.length}');
      if (refreshedState.recent.isNotEmpty) {
        debugPrint('   Most recent: ${refreshedState.recent.first.logType} at ${refreshedState.recent.first.time}');
      }
      if (refreshedState.recent.isNotEmpty) {
        debugPrint('Most recent event: ${refreshedState.recent.first.logType} at ${refreshedState.recent.first.time}');
      }
    } catch (e, stackTrace) {
      // Log the full error details for debugging
      debugPrint('=== CHECK-IN ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // If online check-in fails, queue it for offline sync
      try {
        await OfflineQueue.enqueueAttendance(action);
        await _refresh(current);
        debugPrint('Check-in queued for offline sync');
      } catch (queueError) {
        debugPrint('Failed to queue check-in: $queueError');
      }
      
      // Convert API errors to StateError with readable messages
      if (e is StateError) {
        rethrow;
      } else {
        // Extract error message from DioException or other exceptions
        final errorMsg = e.toString();
        debugPrint('Wrapping error as StateError: $errorMsg');
        throw StateError(errorMsg);
      }
    }
  }
}

DateTime _startOfWeekLocal(DateTime d) {
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

