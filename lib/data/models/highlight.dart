import 'dart:ui' show Color;

/// Colores de subrayado.
enum HighlightColor {
  oro,
  verde,
  azul,
  rosa;

  String get label => switch (this) {
    HighlightColor.oro => 'Oro',
    HighlightColor.verde => 'Verde',
    HighlightColor.azul => 'Azul',
    HighlightColor.rosa => 'Rosa',
  };

  /// Color base (se pinta con transparencia sobre el texto).
  Color get color => switch (this) {
    HighlightColor.oro => const Color(0xFFC9A45C),
    HighlightColor.verde => const Color(0xFF7DB46C),
    HighlightColor.azul => const Color(0xFF6C9BD2),
    HighlightColor.rosa => const Color(0xFFD9839B),
  };
}

/// Subrayado o nota.
///
/// - EPUB/DOCX: [blockIndex] + [start]/[end] (posiciones dentro del texto
///   del bloque).
/// - PDF: [page] y, si se seleccionó texto, [text].
/// - Nota sin texto: [text] vacío.
class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.text,
    required this.createdAt,
    this.blockIndex,
    this.start,
    this.end,
    this.page,
    this.note,
    this.color = HighlightColor.oro,
    this.updatedAt,
  });

  final String id;
  final String bookId;

  /// Texto citado (copia, para mostrarlo sin abrir el libro).
  final String text;
  final int? blockIndex;
  final int? start;
  final int? end;
  final int? page;
  final String? note;
  final HighlightColor color;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasNote => note != null && note!.trim().isNotEmpty;
  bool get isPageNote => text.isEmpty;

  /// Orden de lectura dentro del libro.
  int get sortKey => blockIndex != null
      ? blockIndex! * 100000 + (start ?? 0)
      : (page ?? 0) * 100000;

  Highlight copyWith({
    String? note,
    bool clearNote = false,
    HighlightColor? color,
  }) => Highlight(
    id: id,
    bookId: bookId,
    text: text,
    createdAt: createdAt,
    blockIndex: blockIndex,
    start: start,
    end: end,
    page: page,
    note: clearNote ? null : (note ?? this.note),
    color: color ?? this.color,
    updatedAt: DateTime.now(),
  );
}
