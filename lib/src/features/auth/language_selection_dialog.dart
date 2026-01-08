import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_texts.dart';

class LanguageSelectionDialog extends ConsumerWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use a simple locale for dialog display (default to English for dialog text)
    final currentLocale = ref.read(appLocaleProvider);
    
    return PopScope(
      canPop: false, // Prevent dismissing without selection
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          currentLocale.languageCode == 'ar' ? 'اختر لغتك المفضلة' : 'Select Your Preferred Language',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _LanguageOption(
              icon: Icons.language_rounded,
              title: currentLocale.languageCode == 'ar' ? 'الإنجليزية' : 'English',
              isSelected: currentLocale.languageCode == 'en',
              onTap: () {
                ref.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 12),
            _LanguageOption(
              icon: Icons.language_rounded,
              title: currentLocale.languageCode == 'ar' ? 'العربية' : 'العربية',
              isSelected: currentLocale.languageCode == 'ar',
              onTap: () {
                ref.read(appLocaleProvider.notifier).setLocale(const Locale('ar'));
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C4CA5).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1C4CA5) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1C4CA5) : const Color(0xFF6B7280),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF1C4CA5) : const Color(0xFF1F2937),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1C4CA5),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

