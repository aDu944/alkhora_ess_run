import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../l10n/app_texts.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(title: t.settings),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('Language / اللغة'),
                    subtitle: const Text('Auto • English • العربية'),
                    onTap: () => _showLanguageSheet(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(t.logout),
                    onTap: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Modules'),
            _Grid(
              items: [
                _Item(label: t.leave, icon: Icons.beach_access_rounded, route: '/home/leave'),
                _Item(label: t.attendance, icon: Icons.event_available_rounded, route: '/home/attendance'),
                _Item(label: t.payslips, icon: Icons.receipt_long_rounded, route: '/home/payslips'),
                _Item(label: t.expenses, icon: Icons.request_quote_rounded, route: '/home/expenses'),
                _Item(label: t.announcements, icon: Icons.campaign_rounded, route: '/home/announcements'),
                _Item(label: t.profile, icon: Icons.badge_rounded, route: '/home/profile'),
                _Item(label: t.holidays, icon: Icons.calendar_month_rounded, route: '/home/holidays'),
                _Item(label: t.documents, icon: Icons.description_rounded, route: '/home/documents'),
                _Item(label: t.approvals, icon: Icons.fact_check_rounded, route: '/home/approvals'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Auto'),
                onTap: () {
                  ref.read(appLocaleProvider.notifier).state = null;
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('English'),
                onTap: () {
                  ref.read(appLocaleProvider.notifier).state = const Locale('en');
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('العربية'),
                onTap: () {
                  ref.read(appLocaleProvider.notifier).state = const Locale('ar');
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _Item {
  _Item({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, i) {
        final it = items[i];
        return InkWell(
          onTap: () => context.push(it.route),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(it.icon, size: 28),
                  const Spacer(),
                  Text(
                    it.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

