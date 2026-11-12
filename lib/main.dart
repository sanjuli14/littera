import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'app/app_info.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/file_store.dart';
import 'data/hive/hive_setup.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'features/updates/update_service.dart';
import 'features/updates/updates_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  final storage = await AppStorage.init();
  final FileStore fileStore = kIsWeb
      ? HiveFileStore(Hive.box<Uint8List>(HiveBoxes.files))
      : IoFileStore(storage);

  // Recordatorios de lectura: notificaciones locales (no en Web).
  ReminderScheduler reminders = NoopReminderScheduler();
  if (!kIsWeb) {
    try {
      final local = LocalReminderScheduler();
      await local.init();
      reminders = local;
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
    }
  }

  // Actualizaciones desde GitHub Releases (solo Android).
  var version = AppInfo.appVersion;
  UpdateService? updates;
  if (!kIsWeb) {
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    updates = UpdateService(
      client: http.Client(),
      meta: Hive.box<dynamic>(HiveBoxes.meta),
      currentVersion: version,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        reminderSchedulerProvider.overrideWithValue(reminders),
        currentVersionProvider.overrideWithValue(version),
        updateServiceProvider.overrideWithValue(updates),
      ],
      child: const LitteraApp(),
    ),
  );
}
