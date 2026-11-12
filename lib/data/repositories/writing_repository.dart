import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/file_store.dart';
import '../../features/library/import/cover_processor.dart';
import '../../features/writing/word_count.dart';
import '../hive/hive_setup.dart';
import '../models/manuscript.dart';

/// Máximo de versiones automáticas por capítulo (las manuales no cuentan).
const maxAutoVersions = 30;

class WritingRepository {
  WritingRepository({
    required this.manuscripts,
    required this.chapters,
    required this.versions,
    required this.entities,
    required this.log,
    required this.files,
  });

  final Box<Manuscript> manuscripts;
  final Box<Chapter> chapters;
  final Box<ChapterVersion> versions;
  final Box<StoryEntity> entities;

  /// `'<manuscriptId>|<día>'` → `[palabras al empezar el día, palabras al final]`.
  final Box<dynamic> log;
  final FileStore files;
  static const _uuid = Uuid();

  // ----------------------------------------------------------- Manuscritos

  Manuscript? manuscript(String id) => manuscripts.get(id);

  List<Chapter> chaptersOf(String manuscriptId) =>
      chapters.values.where((c) => c.manuscriptId == manuscriptId).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  int totalWords(String manuscriptId) =>
      chaptersOf(manuscriptId).fold(0, (sum, c) => sum + c.wordCount);

  /// Crea un manuscrito con un primer capítulo vacío.
  Future<Manuscript> createManuscript(String title) async {
    final now = DateTime.now();
    final m = Manuscript(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Sin título' : title.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await manuscripts.put(m.id, m);
    await addChapter(m.id);
    return m;
  }

  Future<void> updateManuscript(Manuscript m) => manuscripts.put(m.id, m);

  Future<bool> setCover(Manuscript m, Uint8List imageBytes) async {
    final processed = await processCover(imageBytes);
    if (processed == null) return false;
    final ref = await files.write(
      FileArea.covers,
      'ms_${m.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      processed,
    );
    final current = manuscripts.get(m.id) ?? m;
    final old = current.coverRef;
    await manuscripts.put(m.id, current.copyWith(coverRef: ref));
    if (old != null && old != ref) await files.delete(old);
    return true;
  }

  Future<void> removeCover(Manuscript m) async {
    final current = manuscripts.get(m.id) ?? m;
    final old = current.coverRef;
    await manuscripts.put(m.id, current.copyWith(clearCover: true));
    if (old != null) await files.delete(old);
  }

  /// Borra el manuscrito y todo lo suyo (capítulos, versiones, fichas…).
  Future<void> deleteManuscript(Manuscript m) async {
    final chapterIds = chaptersOf(m.id).map((c) => c.id).toSet();
    await chapters.deleteAll(chapterIds);
    await versions.deleteAll(
      versions.values
          .where((v) => v.manuscriptId == m.id)
          .map((v) => v.id)
          .toList(),
    );
    await entities.deleteAll(
      entities.values
          .where((e) => e.manuscriptId == m.id)
          .map((e) => e.id)
          .toList(),
    );
    await log.deleteAll(
      log.keys.where((k) => k is String && k.startsWith('${m.id}|')).toList(),
    );
    if (m.coverRef != null) await files.delete(m.coverRef!);
    await manuscripts.delete(m.id);
  }

  Future<void> _touch(String manuscriptId) async {
    final m = manuscripts.get(manuscriptId);
    if (m != null) await manuscripts.put(m.id, m.copyWith());
  }

  // ------------------------------------------------------------- Capítulos

  Future<Chapter> addChapter(String manuscriptId, {String? title}) async {
    final existing = chaptersOf(manuscriptId);
    final now = DateTime.now();
    final chapter = Chapter(
      id: _uuid.v4(),
      manuscriptId: manuscriptId,
      title: (title?.trim().isNotEmpty ?? false)
          ? title!.trim()
          : 'Capítulo ${existing.length + 1}',
      order: existing.isEmpty ? 0 : existing.last.order + 1,
      createdAt: now,
      updatedAt: now,
    );
    await chapters.put(chapter.id, chapter);
    await _touch(manuscriptId);
    return chapter;
  }

  Future<void> renameChapter(Chapter c, String title) async {
    // Se relee: la copia recibida puede tener un orden o contenido viejos.
    final latest = chapters.get(c.id);
    if (latest == null || title.trim().isEmpty) return;
    await chapters.put(c.id, latest.copyWith(title: title.trim()));
  }

  Future<void> deleteChapter(Chapter c) async {
    await versions.deleteAll(
      versions.values
          .where((v) => v.chapterId == c.id)
          .map((v) => v.id)
          .toList(),
    );
    await chapters.delete(c.id);
    await _touch(c.manuscriptId);
  }

  /// Guarda el nuevo orden (lista completa de ids en orden).
  Future<void> reorderChapters(String manuscriptId, List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final c = chapters.get(ids[i]);
      if (c != null && c.manuscriptId == manuscriptId && c.order != i) {
        await chapters.put(c.id, c.copyWith(order: i));
      }
    }
  }

  /// Guarda el contenido del capítulo y anota las palabras del día.
  Future<void> saveChapterContent(
    String chapterId,
    String content, {
    DateTime? now,
  }) async {
    final c = chapters.get(chapterId);
    if (c == null || c.content == content) return;
    final when = now ?? DateTime.now();
    final words = countWords(plainTextFromDelta(content));
    final before = totalWords(c.manuscriptId);

    await chapters.put(
      c.id,
      c.copyWith(content: content, wordCount: words, updatedAt: when),
    );
    final after = before - c.wordCount + words;

    final key = '${c.manuscriptId}|${dayKey(when)}';
    final entry = log.get(key);
    final start = entry is List && entry.isNotEmpty ? entry[0] as int : before;
    await log.put(key, [start, after]);
    await _touch(c.manuscriptId);
  }

  /// Palabras escritas hoy en el manuscrito (puede ser 0 si se borró texto).
  int wordsToday(String manuscriptId, {DateTime? now}) {
    final entry = log.get('$manuscriptId|${dayKey(now ?? DateTime.now())}');
    if (entry is! List || entry.length < 2) return 0;
    final diff = (entry[1] as int) - (entry[0] as int);
    return diff < 0 ? 0 : diff;
  }

  // ------------------------------------------------------------- Versiones

  List<ChapterVersion> versionsOf(String chapterId) =>
      versions.values.where((v) => v.chapterId == chapterId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Guarda una copia del contenido actual del capítulo.
  /// Devuelve `null` si no hay nada nuevo que guardar.
  Future<ChapterVersion?> snapshot(
    String chapterId, {
    bool manual = false,
    String? label,
    String? content,
  }) async {
    final c = chapters.get(chapterId);
    if (c == null) return null;
    final text = content ?? c.content;
    if (text.isEmpty) return null;
    final latest = versionsOf(chapterId).firstOrNull;
    if (!manual && latest != null && latest.content == text) return null;

    final version = ChapterVersion(
      id: _uuid.v4(),
      chapterId: c.id,
      manuscriptId: c.manuscriptId,
      content: text,
      wordCount: countWords(plainTextFromDelta(text)),
      createdAt: DateTime.now(),
      manual: manual,
      label: label,
    );
    await versions.put(version.id, version);
    await _pruneAuto(chapterId);
    return version;
  }

  Future<void> _pruneAuto(String chapterId) async {
    final autos = versionsOf(chapterId).where((v) => !v.manual).toList();
    if (autos.length <= maxAutoVersions) return;
    await versions.deleteAll(
      autos.skip(maxAutoVersions).map((v) => v.id).toList(),
    );
  }

  /// Restaura una versión. Antes guarda el estado actual por si acaso.
  Future<void> restoreVersion(ChapterVersion v) async {
    final c = chapters.get(v.chapterId);
    if (c == null) return;
    await snapshot(c.id, label: 'Antes de restaurar');
    await saveChapterContent(c.id, v.content);
  }

  Future<void> deleteVersion(String id) => versions.delete(id);

  // ---------------------------------------------------------------- Fichas

  List<StoryEntity> entitiesOf(String manuscriptId) =>
      entities.values.where((e) => e.manuscriptId == manuscriptId).toList()
        ..sort((a, b) {
          final byKind = a.kind.index.compareTo(b.kind.index);
          return byKind != 0
              ? byKind
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  Future<StoryEntity> addEntity(
    String manuscriptId, {
    required EntityKind kind,
    required String name,
    String description = '',
  }) async {
    final now = DateTime.now();
    final e = StoryEntity(
      id: _uuid.v4(),
      manuscriptId: manuscriptId,
      kind: kind,
      name: name.trim().isEmpty ? 'Sin nombre' : name.trim(),
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await entities.put(e.id, e);
    return e;
  }

  Future<void> updateEntity(StoryEntity e) => entities.put(e.id, e);

  Future<void> deleteEntity(String id) => entities.delete(id);
}

// -------------------------------------------------------------- Providers

final manuscriptsBoxProvider = Provider<Box<Manuscript>>(
  (ref) => Hive.box<Manuscript>(HiveBoxes.manuscripts),
);
final chaptersBoxProvider = Provider<Box<Chapter>>(
  (ref) => Hive.box<Chapter>(HiveBoxes.chapters),
);
final versionsBoxProvider = Provider<Box<ChapterVersion>>(
  (ref) => Hive.box<ChapterVersion>(HiveBoxes.versions),
);
final entitiesBoxProvider = Provider<Box<StoryEntity>>(
  (ref) => Hive.box<StoryEntity>(HiveBoxes.entities),
);
final writingLogBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>(HiveBoxes.writingLog),
);

final writingRepositoryProvider = Provider<WritingRepository>(
  (ref) => WritingRepository(
    manuscripts: ref.watch(manuscriptsBoxProvider),
    chapters: ref.watch(chaptersBoxProvider),
    versions: ref.watch(versionsBoxProvider),
    entities: ref.watch(entitiesBoxProvider),
    log: ref.watch(writingLogBoxProvider),
    files: ref.watch(fileStoreProvider),
  ),
);

Stream<List<T>> _watch<T>(Box<T> box) async* {
  yield box.values.toList();
  yield* box.watch().map((_) => box.values.toList());
}

final manuscriptsProvider = StreamProvider<List<Manuscript>>(
  (ref) => _watch(ref.watch(manuscriptsBoxProvider))
      .map((list) => list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))),
);

final allChaptersProvider = StreamProvider<List<Chapter>>(
  (ref) => _watch(ref.watch(chaptersBoxProvider)),
);

final allEntitiesProvider = StreamProvider<List<StoryEntity>>(
  (ref) => _watch(ref.watch(entitiesBoxProvider)),
);

final allVersionsProvider = StreamProvider<List<ChapterVersion>>(
  (ref) => _watch(ref.watch(versionsBoxProvider)),
);

/// Cambia cuando se escribe (para refrescar "palabras de hoy").
final writingLogProvider = StreamProvider<int>(
  (ref) => _watch(ref.watch(writingLogBoxProvider)).map((l) => l.length),
);

final manuscriptProvider = Provider.family<Manuscript?, String>((ref, id) {
  final list = ref.watch(manuscriptsProvider).value ?? const <Manuscript>[];
  return list.where((m) => m.id == id).firstOrNull;
});

final chaptersOfProvider = Provider.family<List<Chapter>, String>((ref, id) {
  final all = ref.watch(allChaptersProvider).value ?? const <Chapter>[];
  return all.where((c) => c.manuscriptId == id).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
});

final entitiesOfProvider = Provider.family<List<StoryEntity>, String>((
  ref,
  id,
) {
  ref.watch(allEntitiesProvider);
  return ref.read(writingRepositoryProvider).entitiesOf(id);
});

final versionsOfProvider = Provider.family<List<ChapterVersion>, String>((
  ref,
  chapterId,
) {
  ref.watch(allVersionsProvider);
  return ref.read(writingRepositoryProvider).versionsOf(chapterId);
});

final wordsTodayProvider = Provider.family<int, String>((ref, manuscriptId) {
  ref.watch(writingLogProvider);
  return ref.read(writingRepositoryProvider).wordsToday(manuscriptId);
});
