import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as p;

import 'app_storage.dart';

/// Carpeta lógica dentro del almacén.
enum FileArea { books, covers }

/// Guarda los archivos binarios de la app (libros y carátulas).
///
/// Las referencias son relativas (`books/abc.epub`), así el backup y la
/// restauración no dependen de rutas absolutas del dispositivo.
abstract class FileStore {
  Future<String> write(FileArea area, String fileName, Uint8List bytes);
  Future<Uint8List?> read(String ref);
  Future<void> delete(String ref);

  /// Imagen lista para pintar (carátulas). `null` si no existe.
  ImageProvider? image(String ref);

  static String refFor(FileArea area, String fileName) =>
      '${area.name}/$fileName';
}

/// Implementación con sistema de archivos (Android, escritorio).
class IoFileStore implements FileStore {
  IoFileStore(this.storage);

  final AppStorage storage;

  File _file(String ref) => File(p.join(storage.root!.path, ref));

  @override
  Future<String> write(FileArea area, String fileName, Uint8List bytes) async {
    final ref = FileStore.refFor(area, fileName);
    final file = _file(ref);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async {
    final file = _file(ref);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String ref) async {
    final file = _file(ref);
    if (await file.exists()) await file.delete();
  }

  @override
  ImageProvider? image(String ref) {
    final file = _file(ref);
    return file.existsSync() ? FileImage(file) : null;
  }
}

/// Implementación sobre una box de Hive (Web → IndexedDB).
class HiveFileStore implements FileStore {
  HiveFileStore(this.box);

  final Box<Uint8List> box;

  @override
  Future<String> write(FileArea area, String fileName, Uint8List bytes) async {
    final ref = FileStore.refFor(area, fileName);
    await box.put(ref, bytes);
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async => box.get(ref);

  @override
  Future<void> delete(String ref) => box.delete(ref);

  @override
  ImageProvider? image(String ref) {
    final bytes = box.get(ref);
    return bytes == null ? null : MemoryImage(bytes);
  }
}

/// Se sobrescribe en `main` según la plataforma.
final fileStoreProvider = Provider<FileStore>(
  (ref) => throw UnimplementedError('fileStoreProvider sin inicializar'),
);
