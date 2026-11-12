import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../features/reminders/reminder_scheduler.dart';
import '../features/reminders/reminder_sync.dart';
import 'router.dart';
import 'routes.dart';
import 'theme/littera_theme.dart';

class LitteraApp extends ConsumerStatefulWidget {
  const LitteraApp({super.key});

  @override
  ConsumerState<LitteraApp> createState() => _LitteraAppState();
}

class _LitteraAppState extends ConsumerState<LitteraApp> {
  StreamSubscription<String>? _openBook;

  @override
  void initState() {
    super.initState();
    // Al tocar un recordatorio se abre ese libro en el lector.
    _openBook = ref
        .read(reminderSchedulerProvider)
        .openBookRequests
        .listen(_openReader);
  }

  void _openReader(String bookId) {
    if (ref.read(libraryRepositoryProvider).getBook(bookId) == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(routerProvider).push(Routes.reader(bookId)),
    );
  }

  @override
  void dispose() {
    _openBook?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderSyncProvider); // mantiene los avisos al día
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
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
