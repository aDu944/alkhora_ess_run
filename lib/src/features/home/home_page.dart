import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/device/device_services.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/time/providers.dart';
import '../../features/auth/auth_controller.dart';
import '../../l10n/app_texts.dart';
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

    final greeting = _greeting(now);
    final displayName = (att.valueOrNull?.employeeName?.isNotEmpty == true)
        ? att.valueOrNull!.employeeName!
        : (auth?.user ?? '—');

    return Scaffold(
      body: Stack(
        children: [
          const _Background(),
          SafeArea(
        child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
                  _HeaderRow(
                    greeting: greeting,
                    name: displayName,
                    statusText: att.valueOrNull == null
                        ? 'Currently: —'
                        : 'Currently: ${(att.valueOrNull!.lastLogType == 'IN') ? 'On the Clock' : 'Off the Clock'}',
                    onProfileTap: () => context.push('/home/more'),
                  ),
                  const SizedBox(height: 18),
                  _HeroClock(now: now),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: _RecentActivitySheet(
                      now: now,
                      recent: att.valueOrNull?.recent ?? const <CheckinEvent>[],
                    ),
                  ),
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

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _friendlyError(AppTexts t, String msg) {
  // Handle error codes with prefixes (e.g., "api_error: ...", "checkin_failed: ...")
  if (msg.startsWith('api_error: ')) {
    final apiMsg = msg.substring('api_error: '.length);
    return 'API Error: $apiMsg';
  }
  if (msg.startsWith('checkin_failed: ')) {
    final failMsg = msg.substring('checkin_failed: '.length);
    return 'Check-in failed: $failMsg';
  }
  
  switch (msg) {
    case 'location_permission_required':
      return t.locationPermissionRequired;
    case 'mock_location_detected':
      return 'Mock location detected. Disable GPS spoofing to continue.';
    case 'geofence_locked':
    case 'location_services_disabled':
      return 'You must be within the office geofence.';
    case 'biometric_failed':
      return 'Biometric verification failed.';
    case 'time_service_unavailable':
      return 'Unable to get system time. Please try again.';
    case 'user_not_authenticated':
      return 'User not authenticated. Please log in again.';
    default:
      // Include the actual error message for debugging
      if (msg != 'unknown' && !msg.startsWith('Unable to mark attendance')) {
        return 'Unable to mark attendance: $msg';
      }
      return 'Unable to mark attendance. Please try again.';
  }
}

Future<void> _handleError(BuildContext context, AppTexts t, String msg) async {
  final errorText = _friendlyError(t, msg);
  
  if (msg == 'location_permission_required') {
    // Show dialog with option to open settings
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(errorText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF111827).withOpacity(0.06)),
          ),
          child: Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4B5563)),
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
    final time = DateFormat('HH:mm').format(now);
    final date = DateFormat('EEE, MMM d').format(now);

    return Column(
      children: [
        Text(
          time,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: 0.6,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date,
          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _MainActionSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final locked = state.locked;
    final next = state.nextLogType;
    final isIn = next == 'IN';

    final buttonText = locked ? 'Locked' : (isIn ? 'Tap to Check In' : 'Tap to Check Out');
    final gradient = locked
        ? const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFFE2E8F0)])
        : isIn
            ? const LinearGradient(colors: [Color(0xFF0B7A75), Color(0xFF14A085)])
            : const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]);

    String? helper;
    if (state.mockLocationDetected) {
      helper = 'Mock location detected';
    } else if (state.geofenceEnabled && !state.withinGeofence && state.distanceMeters != null) {
      helper = 'Outside geofence • ${state.distanceMeters!.toStringAsFixed(0)}m away';
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _PunchButton(
            key: ValueKey<String>('btn_${locked ? 'locked' : next}'),
            enabled: !locked,
            gradient: gradient,
            text: buttonText,
            ripple: locked ? const AlwaysStoppedAnimation(0) : ripple,
            onPressed: onTap,
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
                helper ?? 'You are at: Downtown Office (Verified)',
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
    required this.gradient,
    required this.text,
    required this.ripple,
    required this.onPressed,
  });

  final bool enabled;
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
                      BoxShadow(color: Color(0x330B7A75), blurRadius: 22, offset: Offset(0, 10)),
                      BoxShadow(color: Color(0x220B7A75), blurRadius: 46, offset: Offset(0, 20)),
                    ]
                  : const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10)),
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
                  child: Text(
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
      final paint = Paint()..color = const Color(0xFF0B7A75).withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => oldDelegate.progress != progress;
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.analytics});

  final AttendanceAnalytics? analytics;

  @override
  Widget build(BuildContext context) {
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
            title: 'Hours Today',
            value: todayValue,
            progress: todayProgress,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Weekly Total',
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
      elevation: 0,
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.clamp(0, 1),
                backgroundColor: const Color(0xFFEAEFF4),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF0B7A75)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitySheet extends StatelessWidget {
  const _RecentActivitySheet({required this.now, required this.recent});

  final DateTime now;
  final List<CheckinEvent> recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    CheckinEvent? todayEvent;
    CheckinEvent? yesterdayEvent;
    for (final e in recent) {
      final d = DateUtils.dateOnly(e.time.toLocal());
      if (todayEvent == null && d == today) todayEvent = e;
      if (yesterdayEvent == null && d == yesterday) yesterdayEvent = e;
      if (todayEvent != null && yesterdayEvent != null) break;
    }

    String formatEvent(CheckinEvent? e) {
      if (e == null) return '—';
      final t = DateFormat('HH:mm').format(e.time.toLocal());
      final status = e.logType == 'IN' ? 'Checked In' : 'Checked Out';
      return '$status • $t';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Today', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                    subtitle: Text(formatEvent(todayEvent), style: theme.textTheme.bodyMedium),
                    leading: const Icon(Icons.history_rounded, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Yesterday', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(formatEvent(yesterdayEvent), style: theme.textTheme.bodyMedium),
                    leading: const Icon(Icons.history_rounded, color: Color(0xFF64748B)),
                    trailing: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Quick Note +'),
                    ),
                  ),
                  if (recent.isNotEmpty) ...[
                    const Divider(height: 1),
                    ...recent.take(10).map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              e.logType == 'IN' ? 'Checked In' : 'Checked Out',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              DateFormat('EEE, MMM d • HH:mm').format(e.time.toLocal()),
                              style: theme.textTheme.bodyMedium,
                            ),
                            leading: Icon(
                              e.logType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
        border: Border.all(color: const Color(0xFF111827).withOpacity(0.08)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFF64748B)),
          SizedBox(width: 6),
          Text('Syncing Later', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
