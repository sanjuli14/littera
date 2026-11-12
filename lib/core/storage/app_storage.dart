import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Carpetas internas donde Littera guarda los archivos de libros y carátulas.
///
/// En Web no existe sistema de archivos: ahí los bytes se guardarán en Hive
/// (IndexedDB) y estas rutas quedan en `null`.
class AppStorage {
  AppStorage._(this.root);

  final Directory? root;

  Directory? get booksDir =>
      root == null ? null : Directory(p.join(root!.path, 'books'));
  Directory? get coversDir =>
      root == null ? null : Directory(p.join(root!.path, 'covers'));

  static Future<AppStorage> init({String? rootPath}) async {
    if (kIsWeb) return AppStorage._(null);
    final base = rootPath ?? (await getApplicationDocumentsDirectory()).path;
    final storage = AppStorage._(Directory(p.join(base, 'littera')));
    await storage.booksDir!.create(recursive: true);
    await storage.coversDir!.create(recursive: true);
    return storage;
  }
}

/// Se sobrescribe en `main` con la instancia ya inicializada.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider sin inicializar'),
);
