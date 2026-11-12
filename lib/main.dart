import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import 'app/app.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/file_store.dart';
import 'data/hive/hive_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  final storage = await AppStorage.init();
  final FileStore fileStore = kIsWeb
      ? HiveFileStore(Hive.box<Uint8List>(HiveBoxes.files))
      : IoFileStore(storage);

  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
      ],
      child: const LitteraApp(),
    ),
  );
}
