import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device/device_services.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../core/time/providers.dart';
import '../../features/auth/auth_controller.dart';
import '../../l10n/app_texts.dart';
import '../leave/leave_repository.dart';
import 'attendance_controller.dart';
import 'attendance_models.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  Timer? _ticker;
  static const String _buildStamp = 'home-ui-2026-01-06-01';

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texts(ref);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final att = ref.watch(attendanceControllerProvider);
    final offline = ref.watch(isOfflineProvider);
    final timeSvc = ref.watch(timeSyncServiceProvider).valueOrNull;
    final now = (timeSvc?.nowUtc() ?? DateTime.now().toUtc()).toLocal();

           final greeting = _greeting(now, t);
    final displayName = (att.valueOrNull?.employeeName?.isNotEmpty == true)
        ? att.valueOrNull!.employeeName!
        : (auth?.user ?? '—');

    return Scaffold(
      body: Stack(
        children: [
          const _Background(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _HeaderRow(
                    greeting: greeting,
                    name: displayName,
                    statusText: att.valueOrNull == null
                        ? (t.isAr ? 'حالياً: —' : 'Currently: —')
                        : (att.valueOrNull!.lastLogType == 'IN') ? t.currentlyOnClock : t.currentlyOffClock,
                    onProfileTap: () => context.push('/home/more'),
                  ),
                  const SizedBox(height: 18),
                  _HeroClock(now: now),
                  const SizedBox(height: 24),
                  att.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, __) => _ErrorBanner(onRetry: () => ref.invalidate(attendanceControllerProvider)),
                    data: (s) => _MainActionSection(
                      t: t,
                      state: s,
                      ripple: _rippleCtrl,
                      onTap: () async {
                        final next = s.nextLogType;
                        try {
                          await ref.read(attendanceControllerProvider.notifier).mark(logType: next);
                        } catch (e, stackTrace) {
                          String msg = 'unknown';
                          if (e is StateError) {
                            msg = e.message ?? 'unknown';
                          } else if (e is Exception) {
                            msg = e.toString();
                          } else {
                            msg = e.toString();
                          }
                          // Log the full error for debugging
                          debugPrint('Check-in error: $e');
                          debugPrint('Stack trace: $stackTrace');
                          await _handleError(context, t, msg);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnalyticsRow(analytics: att.valueOrNull?.analytics),
                  const SizedBox(height: 12),
                  const _LeaveBalanceCard(),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: _RecentActivitySheet(
                      now: now,
                      recent: att.valueOrNull?.recent ?? const <CheckinEvent>[],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (offline)
            const Positioned(
              right: 14,
              bottom: 14,
              child: _OfflineIndicator(),
            ),
          if (kDebugMode)
            const Positioned(
              left: 12,
              bottom: 12,
              child: _DebugStamp(text: _buildStamp),
            ),
        ],
      ),
    );
  }
}

String _greeting(DateTime now, AppTexts t) {
  final h = now.hour;
  if (h < 12) return t.goodMorning;
  if (h < 17) return t.goodAfternoon;
  return t.goodEvening;
}

String _friendlyError(AppTexts t, String msg) {
  // Handle error codes with prefixes (e.g., "api_error: ...", "checkin_failed: ...")
  if (msg.startsWith('api_error: ')) {
    final apiMsg = msg.substring('api_error: '.length);
    return '${t.apiError}: $apiMsg';
  }
  if (msg.startsWith('checkin_failed: ')) {
    final failMsg = msg.substring('checkin_failed: '.length);
    return '${t.checkinFailed}: $failMsg';
  }
  
  switch (msg) {
    case 'location_permission_required':
      return t.locationPermissionRequired;
    case 'mock_location_detected':
      return t.mockLocationDetectedMsg;
    case 'geofence_locked':
    case 'location_services_disabled':
      return t.mustBeInGeofence;
    case 'biometric_failed':
      return t.biometricFailed;
    case 'time_service_unavailable':
      return t.timeServiceUnavailable;
    case 'user_not_authenticated':
      return t.userNotAuthenticated;
    default:
      // Check if it's a duplicate check-in error
      if (msg.contains('already recorded') || msg.contains('same timestamp') || msg.contains('already has')) {
        return t.alreadyRecorded;
      }
      // Include the actual error message for debugging
      if (msg != 'unknown' && !msg.startsWith('Unable to mark attendance')) {
        return '${t.unableToMarkAttendance}: $msg';
      }
      return t.unableToMarkAttendanceRetry;
  }
}

Future<void> _handleError(BuildContext context, AppTexts t, String msg) async {
  final errorText = _friendlyError(t, msg);
  
  if (msg == 'location_permission_required') {
    // Show dialog with option to open settings
    final shouldOpen = await showDialog<bool>(
      context: context,
             builder: (ctx) => AlertDialog(
                 title: Text(t.locationPermissionRequiredTitle),
                 content: Text(errorText),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.of(ctx).pop(false),
                     child: Text(t.cancel),
                   ),
                   TextButton(
                     onPressed: () => Navigator.of(ctx).pop(true),
                     child: Text(t.openSettings),
                   ),
                 ],
               ),
    );
    
    if (shouldOpen == true) {
      final opened = await DeviceServices.openLocationSettings();
      if (!opened) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open settings')),
          );
        }
      }
    }
  } else {
    if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
    }
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [
                   Color(0xFFFAFAFA),
                   Color(0xFFFFFFFF),
                 ],
               ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.greeting,
    required this.name,
    required this.statusText,
    required this.onProfileTap,
  });

  final String greeting;
  final String name;
  final String statusText;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(999),
          child: const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFEEF3F6),
            child: Icon(Icons.person, color: Color(0xFF4B5563)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C4CA5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF1C4CA5).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1C4CA5),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroClock extends StatelessWidget {
  const _HeroClock({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('hh:mm a').format(now);
    final date = DateFormat('EEE, MMM d').format(now);

    return Column(
      children: [
        Text(
          time,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 48,
            letterSpacing: 1.2,
            color: const Color(0xFF0F172A),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          date,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MainActionSection extends ConsumerWidget {
  const _MainActionSection({
    required this.t,
    required this.state,
    required this.ripple,
    required this.onTap,
  });

  final AppTexts t;
  final AttendanceViewState state;
  final Animation<double> ripple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final locked = state.locked;
    final next = state.nextLogType;
    final isIn = next == 'IN';

    final buttonText = locked ? t.locked : (isIn ? t.tapToCheckIn : t.tapToCheckOut);
    final gradient = locked
        ? const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFFE2E8F0)])
        : isIn
            ? const LinearGradient(colors: [Color(0xFF1C4CA5), Color(0xFF3B6FD8)])
            : const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]);

    String? helper;
    if (state.mockLocationDetected) {
      helper = t.mockLocationDetected;
    } else if (state.geofenceEnabled && !state.withinGeofence && state.distanceMeters != null) {
      helper = t.isAr 
        ? '${t.outsideGeofence} • ${state.distanceMeters!.toStringAsFixed(0)}م بعيداً'
        : '${t.outsideGeofence} • ${state.distanceMeters!.toStringAsFixed(0)}m away';
    } else if (state.geofenceError == 'location_permission_denied') {
      helper = t.locationPermissionDenied;
    } else if (state.geofenceError == 'location_services_disabled') {
      helper = t.locationServicesDisabled;
    } else if (state.geofenceError != null) {
      helper = '${t.geofenceError}: ${state.geofenceError}';
    }

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Map background
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const _CompactMapBackground(),
                ),
              ),
              // Gradient overlay for better button visibility
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.65),
                      Colors.white.withOpacity(0.55),
                      Colors.white.withOpacity(0.65),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Button on top
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _PunchButton(
                  key: ValueKey<String>('btn_${locked ? 'locked' : next}_${state.syncing ? 'syncing' : 'idle'}'),
                  enabled: !locked && !state.syncing,
                  syncing: state.syncing,
                  gradient: gradient,
                  text: buttonText,
                  ripple: (locked || state.syncing) ? const AlwaysStoppedAnimation(0) : ripple,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_pin, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                helper ?? (state.officeLocationName != null 
                  ? (t.isAr 
                    ? 'أنت في: ${state.officeLocationName} (مُتحقق)'
                    : 'You are at: ${state.officeLocationName} (Verified)')
                  : t.verifiedAt),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PunchButton extends StatelessWidget {
  const _PunchButton({
    super.key,
    required this.enabled,
    required this.syncing,
    required this.gradient,
    required this.text,
    required this.ripple,
    required this.onPressed,
  });

  final bool enabled;
  final bool syncing;
  final LinearGradient gradient;
  final String text;
  final Animation<double> ripple;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = math.min(MediaQuery.sizeOf(context).width, 420.0);
    final diameter = math.min(240.0, size * 0.62);

    return SizedBox(
      height: diameter,
      width: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (enabled)
            AnimatedBuilder(
              animation: ripple,
              builder: (context, _) => CustomPaint(
                painter: _RipplePainter(progress: ripple.value),
                size: Size(diameter, diameter),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: enabled
                  ? const [
                      BoxShadow(color: Color(0x401C4CA5), blurRadius: 24, offset: Offset(0, 12)),
                      BoxShadow(color: Color(0x301C4CA5), blurRadius: 48, offset: Offset(0, 24)),
                    ]
                  : const [
                      BoxShadow(color: Color(0x20000000), blurRadius: 18, offset: Offset(0, 10)),
                    ],
            ),
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: SizedBox(
                height: diameter,
                width: diameter,
                child: Center(
                  child: syncing
                      ? SizedBox(
                          width: diameter * 0.35,
                          height: diameter * 0.35,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                        )
                      : Text(
                          text,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.1,
                          ),
                        ),
                ),
              ),
            ),
              ),
            ],
          ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.38;
    for (final i in [0, 1, 2]) {
      final p = (progress + i * 0.22) % 1.0;
      final radius = base + (size.shortestSide * 0.55) * p;
      final opacity = (1.0 - p).clamp(0.0, 1.0) * 0.18;
      final paint = Paint()..color = const Color(0xFF1C4CA5).withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => oldDelegate.progress != progress;
}

class _CompactMapBackground extends ConsumerStatefulWidget {
  const _CompactMapBackground();

  @override
  ConsumerState<_CompactMapBackground> createState() => _CompactMapBackgroundState();
}

class _CompactMapBackgroundState extends ConsumerState<_CompactMapBackground> {
  Position? _currentPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      // First, try to get last known position for instant display
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = lastKnown;
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            try {
              _mapController.move(LatLng(lastKnown!.latitude, lastKnown.longitude), 16.0);
            } catch (_) {
              // Map not ready yet
            }
          }
        });
      }

      // Then fetch current position in background (non-blocking)
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        return; // Already showing last known position
      }

      final perm = await DeviceServices.ensureLocationPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return; // Already showing last known position
      }

      // Fetch current position with timeout
      try {
        Position? position;
        try {
          position = await DeviceServices.getPosition().timeout(
            const Duration(seconds: 3),
          );
        } on TimeoutException {
          position = lastKnown; // Use last known position if timeout
        }
        
        if (position != null && mounted && position != _currentPosition) {
          setState(() {
            _currentPosition = position;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              try {
                _mapController.move(LatLng(position!.latitude, position.longitude), 16.0);
              } catch (_) {
                // Map not ready yet
              }
            }
          });
        }
      } catch (_) {
        // Already have last known position, continue with that
      }
    } catch (_) {
      // Show gradient background if location unavailable
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentPosition == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1C4CA5).withOpacity(0.05),
              const Color(0xFF3B6FD8).withOpacity(0.05),
            ],
          ),
        ),
      );
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    return Opacity(
      opacity: 0.85,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 16.0,
          minZoom: 16.0,
          maxZoom: 16.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
          onMapReady: () {
            _mapController.move(LatLng(lat, lng), 16.0);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.alkhora.alkhora_ess',
            maxZoom: 19,
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C4CA5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends ConsumerWidget {
  const _AnalyticsRow({required this.analytics});

  final AttendanceAnalytics? analytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final a = analytics ??
        const AttendanceAnalytics(
          todayWorked: Duration.zero,
          weekWorked: Duration.zero,
          todayGoal: Duration(hours: 8),
          weekGoal: Duration(hours: 40),
        );
    final todayProgress =
        a.todayGoal.inSeconds == 0 ? 0.0 : a.todayWorked.inSeconds / a.todayGoal.inSeconds.toDouble();
    final weekProgress = a.weekGoal.inSeconds == 0 ? 0.0 : a.weekWorked.inSeconds / a.weekGoal.inSeconds.toDouble();

    final todayValue = _formatHm(a.todayWorked);
    final weekValue = '${_formatHm(a.weekWorked)} / ${_formatHours(a.weekGoal)}';
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: t.hoursToday,
            value: todayValue,
            progress: todayProgress,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: t.weeklyTotal,
            value: weekValue,
            progress: weekProgress,
          ),
        ),
      ],
    );
  }
}

String _formatHm(Duration d) {
  final totalMinutes = d.inMinutes;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
}

String _formatHours(Duration d) {
  final h = d.inHours;
  return '${h}h';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.progress});

  final String title;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress.clamp(0, 1),
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF1C4CA5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitySheet extends ConsumerWidget {
  const _RecentActivitySheet({required this.now, required this.recent});

  final DateTime now;
  final List<CheckinEvent> recent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    // Get the most recent IN/OUT events for today and yesterday
    CheckinEvent? todayEvent;
    CheckinEvent? yesterdayEvent;
    
    // Sort recent by time (most recent first) and find today's and yesterday's events
    final sortedRecent = List<CheckinEvent>.from(recent);
    sortedRecent.sort((a, b) => b.time.compareTo(a.time)); // Most recent first
    
    for (final e in sortedRecent) {
      final d = DateUtils.dateOnly(e.time.toLocal());
      if (todayEvent == null && d == today) {
        todayEvent = e;
      }
      if (yesterdayEvent == null && d == yesterday) {
        yesterdayEvent = e;
      }
      if (todayEvent != null && yesterdayEvent != null) break;
    }

    String formatEvent(CheckinEvent? e) {
      if (e == null) return '—';
      final timeStr = DateFormat('HH:mm').format(e.time.toLocal());
      final status = e.logType == 'IN' ? t.checkedIn : t.checkedOut;
      final lateIndicator = (e.isLateEntry && e.logType == 'IN') ? ' • ${t.lateEntry}' : '';
      return '$status • $timeStr$lateIndicator';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              t.recentActivity,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      t.today,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        formatEvent(todayEvent),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C4CA5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF1C4CA5), size: 16),
                    ),
                  ),
                  const Divider(height: 0.5),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      t.yesterday,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        formatEvent(yesterdayEvent),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF6B7280), size: 16),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: const Size(0, 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(t.quickNote, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  if (sortedRecent.isNotEmpty) ...[
                    const Divider(height: 1),
                    ...sortedRecent.take(10).map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.logType == 'IN' ? t.checkedIn : t.checkedOut,
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (e.isLateEntry && e.logType == 'IN')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange, width: 1),
                              ),
                              child: Text(
                                t.lateEntry,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          if (e.isEarlyExit && e.logType == 'OUT')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red, width: 1),
                              ),
                              child: Text(
                                t.earlyExit,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[800],
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        DateFormat('EEE, MMM d • HH:mm').format(e.time.toLocal()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (e.isLateEntry && e.logType == 'IN') 
                              ? Colors.orange.withOpacity(0.1)
                              : (e.isEarlyExit && e.logType == 'OUT')
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFF64748B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          e.logType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                          color: (e.isLateEntry && e.logType == 'IN') 
                              ? Colors.orange 
                              : (e.isEarlyExit && e.logType == 'OUT')
                                  ? Colors.red
                                  : const Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _OfflineIndicator extends ConsumerWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
        border: Border.all(color: const Color(0xFF111827).withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(t.syncingLater, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DebugStamp extends StatelessWidget {
  const _DebugStamp({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'BUILD: $text',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retry),
          ),
        ),
      ],
    );
  }
}

// Provider for leave balances on home page
final homeLeaveBalancesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  final leaveAllocRepo = LeaveAllocationRepository(client);
  return leaveAllocRepo.getLeaveBalances(employeeId);
});

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final balances = ref.watch(homeLeaveBalancesProvider);

    return balances.when(
      data: (bals) {
        if (bals.isEmpty) return const SizedBox.shrink();
        
        // Get top 3 leave types with highest balance
        final sortedBalances = List<Map<String, dynamic>>.from(bals);
        sortedBalances.sort((a, b) {
          final aBalance = (a['unused_leaves'] as num?)?.toDouble() ?? 0.0;
          final bBalance = (b['unused_leaves'] as num?)?.toDouble() ?? 0.0;
          return bBalance.compareTo(aBalance);
        });
        final topBalances = sortedBalances.take(3).toList();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => context.push('/home/leave'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C4CA5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.beach_access_rounded, color: Color(0xFF1C4CA5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.leaveBalance,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...topBalances.map((bal) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                bal['leave_type'] as String? ?? '—',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${bal['unused_leaves'] ?? 0} ${t.days}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1C4CA5),
                                  ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
