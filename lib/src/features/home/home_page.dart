import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../features/auth/auth_controller.dart';
import '../../l10n/app_texts.dart';
import 'attendance_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final att = ref.watch(attendanceControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.home),
        actions: [
          IconButton(
            onPressed: () => context.push('/home/more'),
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: t.settings,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _HeaderCard(
                user: auth?.user ?? '-',
                att: att.valueOrNull,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      onPressed: () async {
                        try {
                          await ref.read(attendanceControllerProvider.notifier).mark(logType: 'IN');
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.locationPermissionRequired)),
                          );
                        }
                      },
                      label: Text(t.checkIn),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(84),
                        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () async {
                        try {
                          await ref.read(attendanceControllerProvider.notifier).mark(logType: 'OUT');
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.locationPermissionRequired)),
                          );
                        }
                      },
                      label: Text(t.checkOut),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(84),
                        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    att.when(
                      data: (s) => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: s.syncing
                                  ? null
                                  : () async {
                                      await ref.read(attendanceControllerProvider.notifier).syncPending();
                                    },
                              icon: s.syncing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(s.syncing ? t.syncing : '${t.syncNow} (${s.pendingCount})'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: t.logout,
                            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                            icon: const Icon(Icons.lock_outline_rounded),
                          ),
                        ],
                      ),
                      error: (_, __) => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => ref.invalidate(attendanceControllerProvider),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user, required this.att});
  final String user;
  final AttendanceViewState? att;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastType = att?.lastLogType;
    final lastTime = att?.lastTimeIso;
    String subtitle = '—';
    if (lastType != null && lastTime != null) {
      final dt = DateTime.tryParse(lastTime);
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      subtitle = '${lastType == 'IN' ? 'IN' : 'OUT'} • ${dt != null ? fmt.format(dt.toLocal()) : lastTime}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

