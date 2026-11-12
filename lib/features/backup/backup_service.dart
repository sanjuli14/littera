import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../app/app_info.dart';
import '../../core/storage/file_store.dart';
import '../../data/hive/hive_setup.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/models/highlight.dart';
import '../../data/models/manuscript.dart';
import '../../data/models/shelf.dart';
import '../../data/repositories/highlights_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/writing_repository.dart';
import 'json_codecs.dart';

/// Formato del archivo `.littera` (un ZIP):
///
/// ```
/// manifest.json          versión del formato, fecha, conteos
/// data/books.json        libros (JSON)
/// data/shelves.json      estantes
/// data/settings.json     ajustes
/// data/highlights.json   subrayados y notas
/// data/writing.json      obras: manuscritos, capítulos, versiones, fichas
/// data/reading_log.json  minutos leídos por libro y día
/// files/books/…          archivos de libros (solo en copia completa)
/// files/covers/…         carátulas
/// ```
abstract final class BackupFormat {
  static const id = 'littera-backup';
  static const version = 1;
  static const extension = 'littera';
  static const filesPrefix = 'files/';
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.bookCount,
    required this.shelfCount,
    required this.includesBookFiles,
    this.manuscriptCount = 0,
  });

  final int manuscriptCount;
  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final int bookCount;
  final int shelfCount;
  final bool includesBookFiles;

  Map<String, Object?> toJson() => {
    'format': BackupFormat.id,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toIso8601String(),
    'bookCount': bookCount,
    'shelfCount': shelfCount,
    'manuscriptCount': manuscriptCount,
    'includesBookFiles': includesBookFiles,
  };
}

/// Contenido ya leído y validado de un backup.
class BackupContents {
  const BackupContents({
    required this.manifest,
    required this.books,
    required this.shelves,
    required this.settings,
    required this.files,
    this.highlights = const [],
    this.writing = const WritingData(),
    this.readingLog = const {},
  });

  /// `'<bookId>|<día>'` → segundos leídos.
  final Map<String, int> readingLog;

  final WritingData writing;
  final BackupManifest manifest;
  final List<Highlight> highlights;
  final List<Book> books;
  final List<Shelf> shelves;
  final AppSettings? settings;

  /// Referencia (`books/x.epub`) → bytes.
  final Map<String, Uint8List> files;

  /// Libros cuyo archivo viene en el backup.
  int get booksWithFiles =>
      books.where((b) => files.containsKey(b.fileRef)).length;
}

enum RestoreMode { merge, replace }

class RestoreResult {
  const RestoreResult({
    this.added = 0,
    this.updated = 0,
    this.skipped = 0,
    this.shelvesAdded = 0,
    this.highlightsAdded = 0,
    this.manuscriptsAdded = 0,
    this.manuscriptsUpdated = 0,
  });

  final int manuscriptsAdded;
  final int manuscriptsUpdated;

  final int highlightsAdded;

  /// Libros nuevos añadidos.
  final int added;

  /// Libros que ya estaban y recibieron progreso, estantes o carátula.
  final int updated;

  /// Libros que no se pudieron restaurar porque su archivo no venía.
  final int skipped;
  final int shelvesAdded;
}

class BackupService {
  BackupService({
    required this.books,
    required this.shelves,
    required this.settings,
    required this.meta,
    required this.files,
    required this.highlights,
    required this.writing,
    required this.readingLog,
  });

  final Box<dynamic> readingLog;
  final WritingRepository writing;
  final Box<Highlight> highlights;
  final Box<Book> books;
  final Box<Shelf> shelves;
  final Box<AppSettings> settings;
  final Box<dynamic> meta;
  final FileStore files;

  static const _lastBackupKey = 'lastBackupAt';

  DateTime? get lastBackupAt {
    final raw = meta.get(_lastBackupKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> markBackedUp([DateTime? at]) =>
      meta.put(_lastBackupKey, (at ?? DateTime.now()).toIso8601String());

  /// Nombre sugerido: `littera-2026-11-12.littera`.
  static String suggestedFileName({
    required bool includeBookFiles,
    DateTime? now,
  }) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${d.year}-${two(d.month)}-${two(d.day)}';
    return 'littera-$date${includeBookFiles ? '' : '-datos'}.${BackupFormat.extension}';
  }

  // ---------------------------------------------------------------- Crear

  Future<Uint8List> create({required bool includeBookFiles}) async {
    final allBooks = books.values.toList();
    final allShelves = shelves.values.toList();
    final archive = Archive();

    void addJson(String name, Object json) {
      archive.addFile(
        ArchiveFile.bytes(
          name,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
        ),
      );
    }

    Future<void> addStored(String ref) async {
      final bytes = await files.read(ref);
      if (bytes == null) return; // archivo perdido: se omite
      // Sin comprimir: EPUB, PDF, DOCX y JPEG ya vienen comprimidos.
      archive.addFile(
        ArchiveFile.bytes('${BackupFormat.filesPrefix}$ref', bytes)
          ..compression = CompressionType.none,
      );
    }

    final manifest = BackupManifest(
      formatVersion: BackupFormat.version,
      schemaVersion: currentSchemaVersion,
      appVersion: AppInfo.appVersion,
      createdAt: DateTime.now(),
      bookCount: allBooks.length,
      shelfCount: allShelves.length,
      includesBookFiles: includeBookFiles,
      manuscriptCount: writing.manuscripts.length,
    );
    addJson('manifest.json', manifest.toJson());
    addJson('data/books.json', allBooks.map(bookToJson).toList());
    addJson('data/shelves.json', allShelves.map(shelfToJson).toList());
    addJson(
      'data/highlights.json',
      highlights.values.map(highlightToJson).toList(),
    );
    addJson('data/writing.json', {
      'manuscripts': writing.manuscripts.values.map(manuscriptToJson).toList(),
      'chapters': writing.chapters.values.map(chapterToJson).toList(),
      'versions': writing.versions.values.map(versionToJson).toList(),
      'entities': writing.entities.values.map(entityToJson).toList(),
      'log': {
        for (final key in writing.log.keys)
          if (key is String && writing.log.get(key) is List)
            key: writing.log.get(key),
      },
    });
    addJson('data/reading_log.json', {
      for (final key in readingLog.keys)
        if (key is String && readingLog.get(key) is int)
          key: readingLog.get(key),
    });
    addJson(
      'data/settings.json',
      settingsToJson(settings.get(HiveKeys.appSettings) ?? const AppSettings()),
    );

    for (final book in allBooks) {
      if (includeBookFiles) await addStored(book.fileRef);
      if (book.coverRef != null) await addStored(book.coverRef!);
    }
    for (final m in writing.manuscripts.values) {
      if (m.coverRef != null) await addStored(m.coverRef!);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  // ----------------------------------------------------------------- Leer

  /// Lee y valida un backup sin tocar los datos actuales.
  BackupContents read(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException(
        'El archivo no es una copia de Littera o está dañado.',
      );
    }

    Object? json(String name) {
      final data = archive.findFile(name)?.readBytes();
      if (data == null) return null;
      try {
        return jsonDecode(utf8.decode(data));
      } catch (_) {
        throw BackupException('La copia está dañada ($name ilegible).');
      }
    }

    final m = json('manifest.json');
    if (m is! Map || m['format'] != BackupFormat.id) {
      throw const BackupException('El archivo no es una copia de Littera.');
    }
    final formatVersion = (m['formatVersion'] as num?)?.toInt() ?? 0;
    if (formatVersion > BackupFormat.version) {
      throw const BackupException(
        'Esta copia se hizo con una versión más nueva de Littera. '
        'Actualiza la app para restaurarla.',
      );
    }

    List<T> list<T>(String name, T Function(Map<String, Object?>) parse) {
      final raw = json(name);
      if (raw == null) return [];
      if (raw is! List) throw BackupException('La copia está dañada ($name).');
      final out = <T>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          out.add(parse(item.cast<String, Object?>()));
        } on FormatException {
          // Registro inválido: se omite y se sigue con el resto.
        }
      }
      return out;
    }

    List<T> parseList<T>(Object? raw, T Function(Map<String, Object?>) parse) {
      if (raw is! List) return [];
      final out = <T>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          out.add(parse(item.cast<String, Object?>()));
        } on FormatException {
          // Registro inválido: se omite.
        }
      }
      return out;
    }

    final rawWriting = json('data/writing.json');
    final writingMap = rawWriting is Map ? rawWriting : const {};
    final rawLog = writingMap['log'];
    final writingData = WritingData(
      manuscripts: parseList(writingMap['manuscripts'], manuscriptFromJson),
      chapters: parseList(writingMap['chapters'], chapterFromJson),
      versions: parseList(writingMap['versions'], versionFromJson),
      entities: parseList(writingMap['entities'], entityFromJson),
      log: {
        if (rawLog is Map)
          for (final e in rawLog.entries)
            if (e.key is String &&
                e.value is List &&
                (e.value as List).length == 2 &&
                (e.value as List).every((v) => v is int))
              e.key as String: List<int>.from(e.value as List),
      },
    );

    final rawReading = json('data/reading_log.json');
    final readingMap = <String, int>{
      if (rawReading is Map)
        for (final e in rawReading.entries)
          if (e.key is String && e.value is int && (e.value as int) > 0)
            e.key as String: e.value as int,
    };

    final rawSettings = json('data/settings.json');
    final fileMap = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith(BackupFormat.filesPrefix)) {
        continue;
      }
      final ref = entry.name.substring(BackupFormat.filesPrefix.length);
      // Solo se aceptan rutas dentro de books/ y covers/ (sin "..").
      final safe =
          (ref.startsWith('books/') || ref.startsWith('covers/')) &&
          !ref.contains('..') &&
          !ref.contains('\\');
      final data = entry.readBytes();
      if (safe && data != null) fileMap[ref] = data;
    }

    final bookList = list('data/books.json', bookFromJson);
    final shelfList = list('data/shelves.json', shelfFromJson);
    return BackupContents(
      manifest: BackupManifest(
        formatVersion: formatVersion,
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
        appVersion: (m['appVersion'] as String?) ?? '?',
        createdAt:
            DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        bookCount: bookList.length,
        shelfCount: shelfList.length,
        includesBookFiles: m['includesBookFiles'] == true,
        manuscriptCount: writingData.manuscripts.length,
      ),
      writing: writingData,
      readingLog: readingMap,
      books: bookList,
      shelves: shelfList,
      highlights: list('data/highlights.json', highlightFromJson),
      settings: rawSettings is Map
          ? settingsFromJson(rawSettings.cast<String, Object?>())
          : null,
      files: fileMap,
    );
  }

  // ------------------------------------------------------------ Restaurar

  Future<RestoreResult> restore(BackupContents backup, RestoreMode mode) =>
      switch (mode) {
        RestoreMode.replace => _replace(backup),
        RestoreMode.merge => _merge(backup),
      };

  /// Reemplaza todo. Solo con copia completa: con una de "solo datos" se
  /// perderían los archivos de los libros actuales.
  Future<RestoreResult> _replace(BackupContents backup) async {
    if (!backup.manifest.includesBookFiles) {
      throw const BackupException(
        'Una copia de "solo datos" no se puede usar para reemplazar: '
        'no trae los archivos de los libros. Usa "Fusionar".',
      );
    }
    final restorable = backup.books
        .where((b) => backup.files.containsKey(b.fileRef))
        .map(
          (b) => backup.files.containsKey(b.coverRef)
              ? b
              : b.copyWith(clearCover: true, hasCustomCover: false),
        )
        .toList();

    // 1) Escribir primero los archivos nuevos: si algo falla aquí, los datos
    //    actuales siguen intactos.
    final keepRefs = <String>{};
    for (final book in restorable) {
      for (final ref in [book.fileRef, ?book.coverRef]) {
        final (area, name) = _split(ref);
        await files.write(area, name, backup.files[ref]!);
        keepRefs.add(ref);
      }
    }

    // 2) Sustituir registros.
    final oldBooks = books.values.toList();
    await books.clear();
    await shelves.clear();
    await books.putAll({for (final b in restorable) b.id: b});
    await shelves.putAll({for (final s in backup.shelves) s.id: s});
    final restoredIds = {for (final b in restorable) b.id};
    final restoredHighlights = backup.highlights
        .where((h) => restoredIds.contains(h.bookId))
        .toList();
    await highlights.clear();
    await highlights.putAll({for (final h in restoredHighlights) h.id: h});
    if (backup.settings != null) {
      await settings.put(HiveKeys.appSettings, backup.settings!);
    }
    final oldManuscriptCovers = writing.manuscripts.values
        .map((m) => m.coverRef)
        .whereType<String>()
        .toList();
    final manuscriptCount = await _replaceWriting(backup, keepRefs);
    await readingLog.clear();
    await readingLog.putAll(backup.readingLog);
    for (final ref in oldManuscriptCovers) {
      if (!keepRefs.contains(ref)) await files.delete(ref);
    }

    // 3) Borrar archivos que ya no usa nadie.
    for (final old in oldBooks) {
      for (final ref in [old.fileRef, ?old.coverRef]) {
        if (!keepRefs.contains(ref)) await files.delete(ref);
      }
    }

    return RestoreResult(
      added: restorable.length,
      skipped: backup.books.length - restorable.length,
      shelvesAdded: backup.shelves.length,
      highlightsAdded: restoredHighlights.length,
      manuscriptsAdded: manuscriptCount,
    );
  }

  /// Sustituye todas las obras por las de la copia. Devuelve cuántas hay.
  Future<int> _replaceWriting(
    BackupContents backup,
    Set<String> keepRefs,
  ) async {
    final w = backup.writing;
    final manuscripts = <Manuscript>[];
    for (final m in w.manuscripts) {
      final cover = backup.files[m.coverRef];
      if (m.coverRef != null && cover != null) {
        final (area, name) = _split(m.coverRef!);
        await files.write(area, name, cover);
        keepRefs.add(m.coverRef!);
        manuscripts.add(m);
      } else {
        manuscripts.add(m.copyWith(clearCover: true, updatedAt: m.updatedAt));
      }
    }
    await writing.manuscripts.clear();
    await writing.chapters.clear();
    await writing.versions.clear();
    await writing.entities.clear();
    await writing.log.clear();
    await writing.manuscripts.putAll({for (final m in manuscripts) m.id: m});
    await writing.chapters.putAll({for (final c in w.chapters) c.id: c});
    await writing.versions.putAll({for (final v in w.versions) v.id: v});
    await writing.entities.putAll({for (final e in w.entities) e.id: e});
    await writing.log.putAll(w.log);
    return manuscripts.length;
  }

  /// Fusiona obras: añade las que faltan y, si ya existen, se queda con la
  /// versión editada más recientemente de cada elemento.
  Future<(int added, int updated)> _mergeWriting(BackupContents backup) async {
    final w = backup.writing;
    var added = 0, updated = 0;
    final touched = <String>{};
    final addedIds = <String>{};

    for (final m in w.manuscripts) {
      final local = writing.manuscripts.get(m.id);
      if (local != null && !m.updatedAt.isAfter(local.updatedAt)) continue;
      var incoming = m;
      final cover = backup.files[m.coverRef];
      if (m.coverRef != null && cover != null) {
        if (m.coverRef != local?.coverRef) {
          final (area, name) = _split(m.coverRef!);
          await files.write(area, name, cover);
          if (local?.coverRef != null) await files.delete(local!.coverRef!);
        }
      } else {
        incoming = m.copyWith(
          coverRef: local?.coverRef,
          clearCover: local?.coverRef == null,
          updatedAt: m.updatedAt,
        );
      }
      await writing.manuscripts.put(incoming.id, incoming);
      if (local == null) {
        added++;
        addedIds.add(m.id);
      } else {
        touched.add(m.id);
      }
    }

    for (final c in w.chapters) {
      if (writing.manuscripts.get(c.manuscriptId) == null) continue;
      final local = writing.chapters.get(c.id);
      if (local != null && !c.updatedAt.isAfter(local.updatedAt)) continue;
      // Si se sobrescribe un capítulo local, se guarda antes como versión.
      if (local != null && local.content.isNotEmpty) {
        await writing.snapshot(local.id, label: 'Antes de restaurar copia');
      }
      await writing.chapters.put(c.id, c);
      touched.add(c.manuscriptId);
    }

    for (final v in w.versions) {
      if (writing.versions.containsKey(v.id)) continue;
      if (writing.chapters.get(v.chapterId) == null) continue;
      await writing.versions.put(v.id, v);
    }

    for (final e in w.entities) {
      if (writing.manuscripts.get(e.manuscriptId) == null) continue;
      final local = writing.entities.get(e.id);
      if (local != null && !e.updatedAt.isAfter(local.updatedAt)) continue;
      await writing.entities.put(e.id, e);
      if (local != null) touched.add(e.manuscriptId);
    }

    for (final entry in w.log.entries) {
      if (!writing.log.containsKey(entry.key)) {
        await writing.log.put(entry.key, entry.value);
      }
    }

    updated = touched.difference(addedIds).length;
    return (added, updated);
  }

  /// Añade lo que falta y actualiza lo que ya existe, sin borrar nada.
  Future<RestoreResult> _merge(BackupContents backup) async {
    // Estantes: mismo id, o mismo nombre → se reutiliza el local.
    final shelfIdMap = <String, String>{};
    var shelvesAdded = 0;
    var nextOrder = shelves.values.fold<int>(
      0,
      (max, s) => s.order >= max ? s.order + 1 : max,
    );
    for (final shelf in backup.shelves) {
      final local =
          shelves.get(shelf.id) ??
          shelves.values
              .where((s) => s.name.toLowerCase() == shelf.name.toLowerCase())
              .firstOrNull;
      if (local != null) {
        shelfIdMap[shelf.id] = local.id;
      } else {
        await shelves.put(shelf.id, shelf.copyWith(order: nextOrder++));
        shelfIdMap[shelf.id] = shelf.id;
        shelvesAdded++;
      }
    }
    List<String> mapShelves(List<String> ids) => [
      for (final id in ids) ?shelfIdMap[id],
    ];

    var added = 0, updated = 0, skipped = 0;
    // id del libro en la copia → id local (pueden diferir si coincide por hash).
    final bookIdMap = <String, String>{};
    for (final incoming in backup.books) {
      final local =
          books.get(incoming.id) ??
          (incoming.contentHash.isEmpty
              ? null
              : books.values
                    .where((b) => b.contentHash == incoming.contentHash)
                    .firstOrNull);

      if (local == null) {
        final fileBytes = backup.files[incoming.fileRef];
        if (fileBytes == null) {
          skipped++;
          continue;
        }
        final (area, name) = _split(incoming.fileRef);
        await files.write(area, name, fileBytes);
        var book = incoming.copyWith(shelfIds: mapShelves(incoming.shelfIds));
        final coverBytes = backup.files[incoming.coverRef];
        if (incoming.coverRef != null && coverBytes != null) {
          final (cArea, cName) = _split(incoming.coverRef!);
          await files.write(cArea, cName, coverBytes);
        } else {
          book = book.copyWith(clearCover: true, hasCustomCover: false);
        }
        await books.put(book.id, book);
        bookIdMap[incoming.id] = book.id;
        added++;
        continue;
      }
      bookIdMap[incoming.id] = local.id;

      // Ya existe: se combina.
      var merged = local;
      var changed = false;

      final incomingNewer =
          incoming.lastOpenedAt != null &&
          (local.lastOpenedAt == null ||
              incoming.lastOpenedAt!.isAfter(local.lastOpenedAt!));
      if (incomingNewer) {
        merged = merged.copyWith(
          progress: incoming.progress,
          position: incoming.position,
          status: incoming.status,
          lastOpenedAt: incoming.lastOpenedAt,
        );
        changed = true;
      }

      final unionShelves = {
        ...merged.shelfIds,
        ...mapShelves(incoming.shelfIds),
      }.toList();
      if (unionShelves.length != merged.shelfIds.length) {
        merged = merged.copyWith(shelfIds: unionShelves);
        changed = true;
      }

      final coverBytes = backup.files[incoming.coverRef];
      if (incoming.hasCustomCover &&
          !local.hasCustomCover &&
          coverBytes != null) {
        final ref = await files.write(
          FileArea.covers,
          '${local.id}_${DateTime.now().microsecondsSinceEpoch}.jpg',
          coverBytes,
        );
        if (local.coverRef != null) await files.delete(local.coverRef!);
        merged = merged.copyWith(coverRef: ref, hasCustomCover: true);
        changed = true;
      }

      if (changed) {
        await books.put(merged.id, merged);
        updated++;
      }
    }

    // Subrayados: se añaden los que no existan, apuntando al libro local.
    var highlightsAdded = 0;
    for (final h in backup.highlights) {
      final localBookId = bookIdMap[h.bookId];
      if (localBookId == null || highlights.containsKey(h.id)) continue;
      await highlights.put(
        h.id,
        Highlight(
          id: h.id,
          bookId: localBookId,
          text: h.text,
          blockIndex: h.blockIndex,
          start: h.start,
          end: h.end,
          page: h.page,
          note: h.note,
          color: h.color,
          createdAt: h.createdAt,
          updatedAt: h.updatedAt,
        ),
      );
      highlightsAdded++;
    }

    final (manuscriptsAdded, manuscriptsUpdated) = await _mergeWriting(backup);

    // Lectura: por libro y día se queda el valor mayor (no se suman, porque
    // una copia restaurada dos veces duplicaría los minutos).
    for (final entry in backup.readingLog.entries) {
      final sep = entry.key.indexOf('|');
      if (sep <= 0) continue;
      final localBook = bookIdMap[entry.key.substring(0, sep)];
      if (localBook == null) continue;
      final key = '$localBook${entry.key.substring(sep)}';
      final current = readingLog.get(key);
      if (current is! int || entry.value > current) {
        await readingLog.put(key, entry.value);
      }
    }

    return RestoreResult(
      added: added,
      updated: updated,
      skipped: skipped,
      shelvesAdded: shelvesAdded,
      highlightsAdded: highlightsAdded,
      manuscriptsAdded: manuscriptsAdded,
      manuscriptsUpdated: manuscriptsUpdated,
    );
  }

  static (FileArea, String) _split(String ref) {
    final slash = ref.indexOf('/');
    final area = FileArea.values.byName(ref.substring(0, slash));
    return (area, ref.substring(slash + 1));
  }
}

final metaBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>(HiveBoxes.meta),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    books: ref.watch(booksBoxProvider),
    shelves: ref.watch(shelvesBoxProvider),
    settings: ref.watch(settingsBoxProvider),
    meta: ref.watch(metaBoxProvider),
    files: ref.watch(fileStoreProvider),
    highlights: ref.watch(highlightsBoxProvider),
    writing: ref.watch(writingRepositoryProvider),
    readingLog: ref.watch(readingLogBoxProvider),
  ),
);

/// Obras incluidas en una copia.
class WritingData {
  const WritingData({
    this.manuscripts = const [],
    this.chapters = const [],
    this.versions = const [],
    this.entities = const [],
    this.log = const {},
  });

  final List<Manuscript> manuscripts;
  final List<Chapter> chapters;
  final List<ChapterVersion> versions;
  final List<StoryEntity> entities;
  final Map<String, List<int>> log;
}

/// Fecha de la última copia (se refresca tras exportar).
class LastBackupNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.watch(backupServiceProvider).lastBackupAt;

  Future<void> mark() async {
    final now = DateTime.now();
    await ref.read(backupServiceProvider).markBackedUp(now);
    state = now;
  }

  /// Tras restaurar una copia: existe una copia de esa fecha, así que el
  /// aviso no debe decir "nunca". Solo avanza, nunca retrocede.
  Future<void> markAtLeast(DateTime at) async {
    final current = state;
    if (current != null && !at.isAfter(current)) return;
    await ref.read(backupServiceProvider).markBackedUp(at);
    state = at;
  }
}

final lastBackupProvider = NotifierProvider<LastBackupNotifier, DateTime?>(
  LastBackupNotifier.new,
);
