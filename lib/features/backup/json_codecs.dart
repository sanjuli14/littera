import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/models/highlight.dart';
import '../../data/models/manuscript.dart';
import '../../data/models/shelf.dart';

/// Conversión de modelos a JSON para el backup.
///
/// Se usa JSON (no el binario de Hive) para que el backup sea legible,
/// independiente de los typeId y fácil de migrar entre versiones.
/// Las lecturas son tolerantes: un campo que falte toma su valor por defecto.

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

double _double(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

Map<String, Object?> bookToJson(Book b) => {
  'id': b.id,
  'title': b.title,
  'author': b.author,
  'format': b.format.name,
  'fileRef': b.fileRef,
  'originalFileName': b.originalFileName,
  'fileSize': b.fileSize,
  'contentHash': b.contentHash,
  'addedAt': b.addedAt.toIso8601String(),
  'coverRef': b.coverRef,
  'hasCustomCover': b.hasCustomCover,
  'status': b.status.name,
  'shelfIds': b.shelfIds,
  'progress': b.progress,
  'position': b.position,
  'lastOpenedAt': b.lastOpenedAt?.toIso8601String(),
  'isOwnWork': b.isOwnWork,
  'sourceManuscriptId': b.sourceManuscriptId,
};

Book bookFromJson(Map<String, Object?> j) {
  final format = BookFormat.values
      .where((f) => f.name == j['format'])
      .firstOrNull;
  final id = j['id'];
  final fileRef = j['fileRef'];
  if (id is! String || fileRef is! String || format == null) {
    throw const FormatException('Libro sin id, archivo o formato');
  }
  return Book(
    id: id,
    title: (j['title'] as String?) ?? 'Sin título',
    author: (j['author'] as String?) ?? '',
    format: format,
    fileRef: fileRef,
    originalFileName: (j['originalFileName'] as String?) ?? '',
    fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
    contentHash: (j['contentHash'] as String?) ?? '',
    addedAt: _date(j['addedAt']) ?? DateTime.now(),
    coverRef: j['coverRef'] as String?,
    hasCustomCover: j['hasCustomCover'] == true,
    status: _enum(ReadingStatus.values, j['status'], ReadingStatus.toRead),
    shelfIds: [
      for (final s in (j['shelfIds'] as List?) ?? const [])
        if (s is String) s,
    ],
    progress: _double(j['progress'], 0).clamp(0, 1),
    position: j['position'] as String?,
    lastOpenedAt: _date(j['lastOpenedAt']),
    isOwnWork: j['isOwnWork'] == true,
    sourceManuscriptId: j['sourceManuscriptId'] as String?,
  );
}

Map<String, Object?> shelfToJson(Shelf s) => {
  'id': s.id,
  'name': s.name,
  'order': s.order,
  'createdAt': s.createdAt.toIso8601String(),
};

Shelf shelfFromJson(Map<String, Object?> j) {
  final id = j['id'];
  final name = j['name'];
  if (id is! String || name is! String) {
    throw const FormatException('Estante sin id o nombre');
  }
  return Shelf(
    id: id,
    name: name,
    order: (j['order'] as num?)?.toInt() ?? 0,
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
  );
}

Map<String, Object?> settingsToJson(AppSettings s) => {
  'themePreference': s.themePreference.name,
  'libraryGridView': s.libraryGridView,
  'librarySort': s.librarySort.name,
  'readerTheme': s.readerTheme.name,
  'readerFontSize': s.readerFontSize,
  'readerLineHeight': s.readerLineHeight,
  'readerJustify': s.readerJustify,
};

AppSettings settingsFromJson(Map<String, Object?> j) {
  const d = AppSettings();
  return AppSettings(
    themePreference: _enum(
      AppThemePreference.values,
      j['themePreference'],
      d.themePreference,
    ),
    libraryGridView: (j['libraryGridView'] as bool?) ?? d.libraryGridView,
    librarySort: _enum(LibrarySort.values, j['librarySort'], d.librarySort),
    readerTheme: _enum(ReaderTheme.values, j['readerTheme'], d.readerTheme),
    readerFontSize: _double(
      j['readerFontSize'],
      d.readerFontSize,
    ).clamp(ReaderLimits.minFontSize, ReaderLimits.maxFontSize),
    readerLineHeight: _double(
      j['readerLineHeight'],
      d.readerLineHeight,
    ).clamp(ReaderLimits.minLineHeight, ReaderLimits.maxLineHeight),
    readerJustify: (j['readerJustify'] as bool?) ?? d.readerJustify,
  );
}

Map<String, Object?> highlightToJson(Highlight h) => {
  'id': h.id,
  'bookId': h.bookId,
  'text': h.text,
  'blockIndex': h.blockIndex,
  'start': h.start,
  'end': h.end,
  'page': h.page,
  'note': h.note,
  'color': h.color.name,
  'createdAt': h.createdAt.toIso8601String(),
  'updatedAt': h.updatedAt?.toIso8601String(),
};

Highlight highlightFromJson(Map<String, Object?> j) {
  final id = j['id'];
  final bookId = j['bookId'];
  if (id is! String || bookId is! String) {
    throw const FormatException('Subrayado sin id o libro');
  }
  int? integer(String key) => (j[key] as num?)?.toInt();
  return Highlight(
    id: id,
    bookId: bookId,
    text: (j['text'] as String?) ?? '',
    blockIndex: integer('blockIndex'),
    start: integer('start'),
    end: integer('end'),
    page: integer('page'),
    note: j['note'] as String?,
    color: _enum(HighlightColor.values, j['color'], HighlightColor.oro),
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
    updatedAt: _date(j['updatedAt']),
  );
}

String _requireString(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is! String) throw FormatException('Falta "$key"');
  return v;
}

Map<String, Object?> manuscriptToJson(Manuscript m) => {
  'id': m.id,
  'title': m.title,
  'synopsis': m.synopsis,
  'author': m.author,
  'coverRef': m.coverRef,
  'dailyWordGoal': m.dailyWordGoal,
  'createdAt': m.createdAt.toIso8601String(),
  'updatedAt': m.updatedAt.toIso8601String(),
};

Manuscript manuscriptFromJson(Map<String, Object?> j) => Manuscript(
  id: _requireString(j, 'id'),
  title: (j['title'] as String?) ?? 'Sin título',
  synopsis: (j['synopsis'] as String?) ?? '',
  author: (j['author'] as String?) ?? '',
  coverRef: j['coverRef'] as String?,
  dailyWordGoal: (j['dailyWordGoal'] as num?)?.toInt() ?? 500,
  createdAt: _date(j['createdAt']) ?? DateTime.now(),
  updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
);

Map<String, Object?> chapterToJson(Chapter c) => {
  'id': c.id,
  'manuscriptId': c.manuscriptId,
  'title': c.title,
  'order': c.order,
  'content': c.content,
  'wordCount': c.wordCount,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': c.updatedAt.toIso8601String(),
};

Chapter chapterFromJson(Map<String, Object?> j) => Chapter(
  id: _requireString(j, 'id'),
  manuscriptId: _requireString(j, 'manuscriptId'),
  title: (j['title'] as String?) ?? 'Capítulo',
  order: (j['order'] as num?)?.toInt() ?? 0,
  content: (j['content'] as String?) ?? '',
  wordCount: (j['wordCount'] as num?)?.toInt() ?? 0,
  createdAt: _date(j['createdAt']) ?? DateTime.now(),
  updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
);

Map<String, Object?> versionToJson(ChapterVersion v) => {
  'id': v.id,
  'chapterId': v.chapterId,
  'manuscriptId': v.manuscriptId,
  'content': v.content,
  'wordCount': v.wordCount,
  'createdAt': v.createdAt.toIso8601String(),
  'manual': v.manual,
  'label': v.label,
};

ChapterVersion versionFromJson(Map<String, Object?> j) => ChapterVersion(
  id: _requireString(j, 'id'),
  chapterId: _requireString(j, 'chapterId'),
  manuscriptId: _requireString(j, 'manuscriptId'),
  content: (j['content'] as String?) ?? '',
  wordCount: (j['wordCount'] as num?)?.toInt() ?? 0,
  createdAt: _date(j['createdAt']) ?? DateTime.now(),
  manual: j['manual'] == true,
  label: j['label'] as String?,
);

Map<String, Object?> entityToJson(StoryEntity e) => {
  'id': e.id,
  'manuscriptId': e.manuscriptId,
  'kind': e.kind.name,
  'name': e.name,
  'description': e.description,
  'createdAt': e.createdAt.toIso8601String(),
  'updatedAt': e.updatedAt.toIso8601String(),
};

StoryEntity entityFromJson(Map<String, Object?> j) => StoryEntity(
  id: _requireString(j, 'id'),
  manuscriptId: _requireString(j, 'manuscriptId'),
  kind: _enum(EntityKind.values, j['kind'], EntityKind.note),
  name: (j['name'] as String?) ?? 'Sin nombre',
  description: (j['description'] as String?) ?? '',
  createdAt: _date(j['createdAt']) ?? DateTime.now(),
  updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
);
