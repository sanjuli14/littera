import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/app_settings.dart';
import '../models/book.dart';
import '../models/shelf.dart';
import 'hive_registrar.g.dart';

/// Nombres de las boxes de Hive.
abstract final class HiveBoxes {
  static const meta = 'meta';
  static const settings = 'settings';
  static const books = 'books';
  static const shelves = 'shelves';

  /// Solo en Web: bytes de libros y carátulas.
  static const files = 'files';
}

/// Claves dentro de las boxes.
abstract final class HiveKeys {
  static const schemaVersion = 'schemaVersion';
  static const appSettings = 'app';
}

/// Versión actual del esquema de datos. Subirla cuando cambien los modelos
/// y añadir el paso correspondiente en [_migrate].
const int currentSchemaVersion = 1;

/// Inicializa Hive, registra adapters, abre boxes y aplica migraciones.
Future<void> initHive({String? path}) async {
  if (path != null) {
    Hive.init(path);
  } else {
    await Hive.initFlutter('littera');
  }
  Hive.registerAdapters();
  await openBoxes();
}

Future<void> openBoxes() async {
  final meta = await Hive.openBox<dynamic>(HiveBoxes.meta);
  await Hive.openBox<AppSettings>(HiveBoxes.settings);
  await Hive.openBox<Book>(HiveBoxes.books);
  await Hive.openBox<Shelf>(HiveBoxes.shelves);
  if (kIsWeb) await Hive.openBox<Uint8List>(HiveBoxes.files);
  await _migrate(meta);
}

Future<void> _migrate(Box<dynamic> meta) async {
  final stored = meta.get(HiveKeys.schemaVersion) as int?;
  if (stored == null) {
    // Instalación nueva.
    await meta.put(HiveKeys.schemaVersion, currentSchemaVersion);
    return;
  }
  if (stored > currentSchemaVersion) {
    debugPrint(
      'Datos de una versión más nueva ($stored) que la app '
      '($currentSchemaVersion).',
    );
    return;
  }
  // Futuras migraciones: for (var v = stored; v < currentSchemaVersion; v++) {...}
  await meta.put(HiveKeys.schemaVersion, currentSchemaVersion);
}
