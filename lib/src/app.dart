import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_texts.dart';
import 'routing/router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    final isArabic = locale.languageCode == 'ar';
    
    // Apply Dubai font only for Arabic language
    final theme = AppTheme.light();
    final themeWithFont = isArabic
        ? theme.copyWith(
            textTheme: theme.textTheme.apply(
              fontFamily: 'Dubai',
            ),
          )
        : theme;
    
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: themeWithFont,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

