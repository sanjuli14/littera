import 'dart:typed_data';

/// Fragmento de texto con estilo.
class TextRun {
  const TextRun(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  TextRun copyWith({String? text}) =>
      TextRun(text ?? this.text, bold: bold, italic: italic);
}

/// Bloque de un documento "fluido" (EPUB, DOCX): se dibuja uno tras otro
/// y la posición de lectura es el índice del bloque.
sealed class DocBlock {
  const DocBlock();
}

class HeadingBlock extends DocBlock {
  const HeadingBlock(this.level, this.runs);
  final int level;
  final List<TextRun> runs;
  String get text => runs.map((r) => r.text).join();
}

enum ParagraphKind { normal, quote, listItem, center, preformatted }

class ParagraphBlock extends DocBlock {
  const ParagraphBlock(this.runs, {this.kind = ParagraphKind.normal});
  final List<TextRun> runs;
  final ParagraphKind kind;
  String get text => runs.map((r) => r.text).join();
}

class ImageBlock extends DocBlock {
  const ImageBlock(this.bytes, {this.alt});
  final Uint8List bytes;
  final String? alt;
}

class SeparatorBlock extends DocBlock {
  const SeparatorBlock();
}

/// Entrada del índice.
class TocEntry {
  const TocEntry(this.title, this.blockIndex, {this.level = 1});
  final String title;
  final int blockIndex;
  final int level;
}

class ReaderDocument {
  const ReaderDocument(this.blocks, this.toc);

  final List<DocBlock> blocks;
  final List<TocEntry> toc;

  bool get isEmpty => blocks.isEmpty;

  /// Entrada del índice que contiene el bloque [index].
  TocEntry? tocEntryFor(int index) {
    TocEntry? current;
    for (final entry in toc) {
      if (entry.blockIndex > index) break;
      current = entry;
    }
    return current;
  }
}

/// Construye bloques a partir de texto con estilos, normalizando espacios.
class BlockBuilder {
  final blocks = <DocBlock>[];
  final _runs = <TextRun>[];

  /// Ids (anclas) vistos que apuntarán al próximo bloque creado.
  final _pendingAnchors = <String>[];
  final anchors = <String, int>{};

  bool get hasPendingText => _runs.any((r) => r.text.trim().isNotEmpty);

  void addText(String text, {bool bold = false, bool italic = false}) {
    if (text.isEmpty) return;
    final last = _runs.isEmpty ? null : _runs.last;
    if (last != null && last.bold == bold && last.italic == italic) {
      _runs[_runs.length - 1] = last.copyWith(text: last.text + text);
    } else {
      _runs.add(TextRun(text, bold: bold, italic: italic));
    }
  }

  void addAnchor(String id) => _pendingAnchors.add(id);

  void _assignAnchors() {
    for (final id in _pendingAnchors) {
      anchors.putIfAbsent(id, () => blocks.length);
    }
    _pendingAnchors.clear();
  }

  /// Cierra el párrafo en curso (si tiene texto).
  void flush({ParagraphKind kind = ParagraphKind.normal, int? headingLevel}) {
    final runs = _normalize(
      _runs,
      keepSpaces: kind == ParagraphKind.preformatted,
    );
    _runs.clear();
    if (runs.isEmpty) return;
    _assignAnchors();
    blocks.add(
      headingLevel != null
          ? HeadingBlock(headingLevel, runs)
          : ParagraphBlock(runs, kind: kind),
    );
  }

  void addBlock(DocBlock block) {
    flush();
    _assignAnchors();
    blocks.add(block);
  }

  static List<TextRun> _normalize(
    List<TextRun> input, {
    bool keepSpaces = false,
  }) {
    if (keepSpaces) {
      final text = input.map((r) => r.text).join();
      return text.trim().isEmpty ? const [] : List.of(input);
    }
    final out = <TextRun>[];
    var prevEndsWithSpace = true; // elimina espacios iniciales
    for (final run in input) {
      // Colapsa espacios, pero respeta los saltos de línea explícitos (<br>).
      var text = run.text
          .replaceAll(RegExp(r'[ \t\r\f ]*\n[ \t\r\f ]*'), '\n')
          .replaceAll(RegExp(r'[ \t\r\f]+'), ' ');
      if (prevEndsWithSpace) text = text.replaceFirst(RegExp(r'^ +'), '');
      if (text.isEmpty) continue;
      prevEndsWithSpace = text.endsWith(' ') || text.endsWith('\n');
      out.add(run.copyWith(text: text));
    }
    // Recorta espacios y saltos finales/iniciales.
    while (out.isNotEmpty) {
      final trimmed = out.last.text.replaceFirst(RegExp(r'[\s]+$'), '');
      if (trimmed.isEmpty) {
        out.removeLast();
      } else {
        out[out.length - 1] = out.last.copyWith(text: trimmed);
        break;
      }
    }
    while (out.isNotEmpty) {
      final trimmed = out.first.text.replaceFirst(RegExp(r'^\s+'), '');
      if (trimmed.isEmpty) {
        out.removeAt(0);
      } else {
        out[0] = out.first.copyWith(text: trimmed);
        break;
      }
    }
    return out;
  }
}

/// Índice de respaldo: títulos de nivel 1 y 2.
List<TocEntry> tocFromHeadings(List<DocBlock> blocks, {int maxLevel = 2}) => [
  for (var i = 0; i < blocks.length; i++)
    if (blocks[i] case HeadingBlock(:final level, :final text)
        when level <= maxLevel && text.trim().isNotEmpty)
      TocEntry(text.trim(), i, level: level),
];
