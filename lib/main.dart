import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/app_storage.dart';
import 'data/hive/hive_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  final storage = await AppStorage.init();

  runApp(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(storage)],
      child: const LitteraApp(),
    ),
  );
}
