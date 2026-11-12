import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';
import 'router.dart';
import 'theme/littera_theme.dart';

class LitteraApp extends ConsumerWidget {
  const LitteraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(settingsProvider.select((s) => s.themePreference));

    return MaterialApp.router(
      title: 'Littera',
      debugShowCheckedModeBanner: false,
      theme: pref == AppThemePreference.sepia
          ? LitteraTheme.sepia
          : LitteraTheme.light,
      darkTheme: LitteraTheme.dark,
      themeMode: switch (pref) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light || AppThemePreference.sepia => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
