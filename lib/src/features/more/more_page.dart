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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t.settings),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Settings Section
            _SectionHeader(title: t.settings),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                _FlatListTile(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF1C4CA5),
                  title: t.language,
                  subtitle: '${t.languageAuto} • ${t.languageEnglish} • ${t.languageArabic}',
                  onTap: () => _showLanguageSheet(context, ref),
                ),
                const _Divider(),
                _FlatListTile(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: t.logout,
                  subtitle: null,
                  onTap: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Modules Section
            _SectionHeader(title: t.modules),
            const SizedBox(height: 12),
            _ModulesGrid(
              items: [
                _ModuleItem(label: t.leave, icon: Icons.beach_access_rounded, route: '/home/leave'),
                _ModuleItem(label: t.attendance, icon: Icons.event_available_rounded, route: '/home/attendance'),
                _ModuleItem(label: t.payslips, icon: Icons.receipt_long_rounded, route: '/home/payslips'),
                _ModuleItem(label: t.expenses, icon: Icons.request_quote_rounded, route: '/home/expenses'),
                _ModuleItem(label: 'Payments', icon: Icons.payment_rounded, route: '/home/payments'),
                _ModuleItem(label: t.announcements, icon: Icons.campaign_rounded, route: '/home/announcements'),
                _ModuleItem(label: t.profile, icon: Icons.badge_rounded, route: '/home/profile'),
                _ModuleItem(label: t.holidays, icon: Icons.calendar_month_rounded, route: '/home/holidays'),
                _ModuleItem(label: t.documents, icon: Icons.description_rounded, route: '/home/documents'),
                _ModuleItem(label: t.approvals, icon: Icons.fact_check_rounded, route: '/home/approvals'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    t.selectLanguage,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  icon: Icons.auto_awesome_rounded,
                  title: t.languageAuto,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).state = null;
                    Navigator.of(ctx).pop();
                  },
                ),
                _LanguageOption(
                  icon: Icons.language_rounded,
                  title: t.languageEnglish,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).state = const Locale('en');
                    Navigator.of(ctx).pop();
                  },
                ),
                _LanguageOption(
                  icon: Icons.language_rounded,
                  title: t.languageArabic,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).state = const Locale('ar');
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class _FlatListTile extends StatelessWidget {
  const _FlatListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1C4CA5), size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  _ModuleItem({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid({required this.items});

  final List<_ModuleItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, i) {
        final it = items[i];
        return InkWell(
          onTap: () => context.push(it.route),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C4CA5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    it.icon,
                    size: 26,
                    color: const Color(0xFF1C4CA5),
                  ),
                ),
                Text(
                  it.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
