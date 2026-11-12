import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../features/reminders/reminder_messages.dart';
import '../features/reminders/reminder_scheduler.dart';
import '../features/reminders/reminder_sync.dart';
import '../features/updates/updates_provider.dart';
import 'router.dart';
import 'routes.dart';
import 'theme/littera_theme.dart';

class LitteraApp extends ConsumerStatefulWidget {
  const LitteraApp({super.key});

  @override
  ConsumerState<LitteraApp> createState() => _LitteraAppState();
}

class _LitteraAppState extends ConsumerState<LitteraApp> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    // Al tocar una notificación: abrir el libro o las novedades.
    _taps = ref.read(reminderSchedulerProvider).taps.listen(_onTap);
    // Buscar versiones nuevas (como mucho una vez al día, con conexión).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(updatesProvider.notifier).checkOnLaunch(),
    );
  }

  void _onTap(String payload) {
    final String? location;
    if (payload == ReminderMessage.updatePayload) {
      location = Routes.whatsNew;
    } else {
      final id = ReminderMessage.bookIdFromPayload(payload);
      location =
          id != null && ref.read(libraryRepositoryProvider).getBook(id) != null
          ? Routes.reader(id)
          : null;
    }
    if (location == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(routerProvider).push(location!),
    );
  }

  @override
  void dispose() {
    _taps?.cancel();
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
