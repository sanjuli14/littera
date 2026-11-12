/// Formatos de libro soportados.
enum BookFormat {
  epub,
  pdf,
  docx;

  String get label => name.toUpperCase();

  static BookFormat? fromExtension(String ext) =>
      switch (ext.toLowerCase().replaceFirst('.', '')) {
        'epub' => BookFormat.epub,
        'pdf' => BookFormat.pdf,
        'docx' => BookFormat.docx,
        _ => null,
      };
}

/// Estado de lectura. Se muestra como los estantes del sistema.
enum ReadingStatus {
  toRead,
  reading,
  finished;

  String get label => switch (this) {
    ReadingStatus.toRead => 'Por leer',
    ReadingStatus.reading => 'Leyendo',
    ReadingStatus.finished => 'Terminado',
  };

  String get shelfLabel => switch (this) {
    ReadingStatus.toRead => 'Por leer',
    ReadingStatus.reading => 'Leyendo',
    ReadingStatus.finished => 'Terminados',
  };
}

/// Un libro de la biblioteca.
///
/// [fileRef] y [coverRef] son nombres relativos dentro del almacén de archivos
/// (nunca rutas absolutas), para que el backup sea portable entre dispositivos.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.fileRef,
    required this.originalFileName,
    required this.fileSize,
    required this.contentHash,
    required this.addedAt,
    this.coverRef,
    this.hasCustomCover = false,
    this.status = ReadingStatus.toRead,
    this.shelfIds = const [],
    this.progress = 0,
    this.position,
    this.lastOpenedAt,
    this.isOwnWork = false,
    this.sourceManuscriptId,
    this.finishedAt,
    this.sourceVersion,
    this.rating = 0,
  });

  final String id;
  final String title;
  final String author;
  final BookFormat format;
  final String fileRef;
  final String originalFileName;
  final int fileSize;

  /// SHA-1 del archivo, para detectar duplicados al importar.
  final String contentHash;
  final DateTime addedAt;

  /// Carátula; `null` = se dibuja una carátula generada.
  final String? coverRef;

  /// `true` si el usuario eligió la carátula a mano.
  final bool hasCustomCover;
  final ReadingStatus status;

  /// Estantes propios a los que pertenece.
  final List<String> shelfIds;

  /// Progreso de lectura de 0 a 1.
  final double progress;

  /// Posición exacta en el lector (formato propio de cada lector).
  final String? position;
  final DateTime? lastOpenedAt;

  /// `true` si es una obra escrita en Littera.
  final bool isOwnWork;

  /// Manuscrito del que se exportó (para actualizarlo al reexportar).
  final String? sourceManuscriptId;

  /// Cuándo se marcó como terminado (para la meta anual).
  final DateTime? finishedAt;

  /// Última edición de la obra cuando se exportó este archivo. Si no cambió,
  /// reexportar no toca el libro (los PDF nunca salen idénticos byte a byte).
  final DateTime? sourceVersion;

  /// Valoración personal de 1 a 5 estrellas (0 = sin valorar).
  final int rating;

  Book copyWith({
    String? title,
    String? author,
    String? coverRef,
    bool clearCover = false,
    bool? hasCustomCover,
    ReadingStatus? status,
    List<String>? shelfIds,
    double? progress,
    String? position,
    DateTime? lastOpenedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? rating,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author ?? this.author,
    format: format,
    fileRef: fileRef,
    originalFileName: originalFileName,
    fileSize: fileSize,
    contentHash: contentHash,
    addedAt: addedAt,
    coverRef: clearCover ? null : (coverRef ?? this.coverRef),
    hasCustomCover: hasCustomCover ?? this.hasCustomCover,
    status: status ?? this.status,
    shelfIds: shelfIds ?? this.shelfIds,
    progress: progress ?? this.progress,
    position: position ?? this.position,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    isOwnWork: isOwnWork,
    sourceManuscriptId: sourceManuscriptId,
    finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    sourceVersion: sourceVersion,
    rating: rating ?? this.rating,
  );
}
