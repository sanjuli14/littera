import '../../core/utils/text_utils.dart';
import '../../data/models/book.dart';
import '../../data/models/highlight.dart';

/// Ubicación legible de un subrayado fuera del lector.
/// En EPUB/DOCX la posición es un índice de bloque, que no dice nada al
/// usuario, así que solo se muestra la página en PDF.
String highlightLocation(Highlight h) =>
    h.page != null ? 'Página ${h.page}' : '';

/// Exporta citas y notas a Markdown, agrupadas por libro.
String buildQuotesMarkdown(
  List<Highlight> highlights,
  Map<String, Book> books, {
  DateTime? now,
}) {
  final out = StringBuffer()
    ..writeln('# Mis citas')
    ..writeln()
    ..writeln(
      '_Exportado desde Littera el ${formatDate(now ?? DateTime.now())}_',
    )
    ..writeln();

  final byBook = <String, List<Highlight>>{};
  for (final h in highlights) {
    (byBook[h.bookId] ??= []).add(h);
  }
  final bookIds = byBook.keys.toList()
    ..sort(
      (a, b) =>
          normalizeForSearch(books[a]?.title ?? '')
              .compareTo(normalizeForSearch(books[b]?.title ?? '')),
    );

  for (final id in bookIds) {
    final book = books[id];
    final title = book?.title ?? 'Libro eliminado';
    final author = book?.author ?? '';
    out
      ..writeln('## $title${author.isEmpty ? '' : ' — $author'}')
      ..writeln();
    final items = byBook[id]!..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    for (final h in items) {
      if (!h.isPageNote) {
        for (final line in h.text.split('\n')) {
          out.writeln('> $line');
        }
        out.writeln();
      }
      if (h.hasNote) {
        out
          ..writeln('**Nota:** ${h.note!.trim()}')
          ..writeln();
      }
      final location = highlightLocation(h);
      out
        ..writeln(
          '<sub>${location.isEmpty ? '' : '$location · '}${formatDate(h.createdAt)}</sub>',
        )
        ..writeln()
        ..writeln('---')
        ..writeln();
    }
  }
  return out.toString();
}
