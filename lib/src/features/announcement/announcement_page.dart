import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'announcement_repository.dart';

final announcementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  final annRepo = AnnouncementRepository(client);
  return annRepo.getRelevantAnnouncements(employeeId: employeeId);
});

class AnnouncementPage extends ConsumerWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final announcements = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.announcements),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(announcementsProvider.future),
        child: announcements.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No announcements', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _AnnouncementCard(announcement: items[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading announcements', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(announcementsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final Map<String, dynamic> announcement;

  @override
  Widget build(BuildContext context) {
    final title = announcement['title'] as String? ?? 'No Title';
    final message = announcement['message'] as String? ?? '';
    final expiresOn = announcement['expires_on'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFF1C4CA5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (expiresOn != null) ...[
              const SizedBox(height: 12),
              Text(
                'Expires: ${_formatDate(expiresOn)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

