import 'dart:convert';

import '../../data/models/manuscript.dart';
import '../reader/document/reader_document.dart';

/// Capítulo listo para exportar.
class CompiledChapter {
  const CompiledChapter(this.title, this.blocks);
  final String title;
  final List<DocBlock> blocks;
}

/// Obra lista para exportar: datos y capítulos en orden.
class CompiledBook {
  const CompiledBook({
    required this.id,
    required this.title,
    required this.author,
    required this.synopsis,
    required this.chapters,
  });

  final String id;
  final String title;
  final String author;
  final String synopsis;
  final List<CompiledChapter> chapters;

  bool get isEmpty => chapters.isEmpty;
}

/// Convierte el Delta de Quill (JSON) en bloques del lector.
///
/// Formato de línea (va en el `\n` que cierra cada línea): `header` (1–3),
/// `blockquote`, `list` (bullet/ordered), `align: center`, `code-block`.
/// Formato en línea: `bold`, `italic`.
List<DocBlock> deltaToBlocks(String deltaJson) {
  if (deltaJson.trim().isEmpty) return const [];
  final Object? ops;
  try {
    ops = jsonDecode(deltaJson);
  } catch (_) {
    // Texto plano heredado: un párrafo por línea.
    final b = BlockBuilder();
    for (final line in deltaJson.split('\n')) {
      b
        ..addText(line)
        ..flush();
    }
    return b.blocks;
  }
  if (ops is! List) return const [];

  final b = BlockBuilder();
  var orderedCounter = 0;

  void endLine(Map attrs) {
    final header = attrs['header'];
    final list = attrs['list'];
    if (list != 'ordered') orderedCounter = 0;

    if (header is int && header > 0) {
      // El título del capítulo es nivel 1; los títulos internos van debajo.
      b.flush(headingLevel: (header + 1).clamp(2, 6));
    } else if (list == 'bullet') {
      b.flush(kind: ParagraphKind.listItem);
    } else if (list == 'ordered') {
      orderedCounter++;
      // El número se antepone al texto ya acumulado.
      b.prependText('$orderedCounter. ');
      b.flush(kind: ParagraphKind.normal);
    } else if (attrs['blockquote'] == true) {
      b.flush(kind: ParagraphKind.quote);
    } else if (attrs['code-block'] != null) {
      b.flush(kind: ParagraphKind.preformatted);
    } else if (attrs['align'] == 'center') {
      b.flush(kind: ParagraphKind.center);
    } else {
      b.flush();
    }
  }

  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String) continue; // imágenes u otros incrustados
    final attrs = op['attributes'] is Map ? op['attributes'] as Map : const {};
    final bold = attrs['bold'] == true;
    final italic = attrs['italic'] == true;

    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        b.addText(parts[i], bold: bold, italic: italic);
      }
      if (i < parts.length - 1) endLine(attrs);
    }
  }
  b.flush();
  return b.blocks;
}

/// Reúne la obra: capítulos en orden, omitiendo los que no tienen texto.
CompiledBook compileManuscript(Manuscript m, List<Chapter> chapters) {
  final sorted = [...chapters]..sort((a, b) => a.order.compareTo(b.order));
  return CompiledBook(
    id: m.id,
    title: m.title,
    author: m.author,
    synopsis: m.synopsis,
    chapters: [
      for (final c in sorted)
        if (deltaToBlocks(c.content) case final blocks when blocks.isNotEmpty)
          CompiledChapter(c.title, blocks),
    ],
  );
}

/// Nombre de archivo seguro: `El faro (borrador).epub` → `el-faro-borrador.epub`.
String exportFileName(String title, String extension) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
  };
  var slug = title.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  slug = slug
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) slug = 'obra';
  if (slug.length > 60) {
    slug = slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
  }
  return '$slug.$extension';
}
