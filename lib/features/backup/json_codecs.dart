import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
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
