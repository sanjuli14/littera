import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'reader_document.dart';

/// Convierte un DOCX en un [ReaderDocument]: párrafos, títulos, negritas,
/// cursivas, listas e imágenes. Las tablas se leen párrafo a párrafo.
ReaderDocument parseDocx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  XmlDocument? readXml(String path) {
    final data = archive.findFile(path)?.readBytes();
    if (data == null) return null;
    return XmlDocument.parse(utf8.decode(data, allowMalformed: true));
  }

  final document = readXml('word/document.xml');
  if (document == null) throw const FormatException('DOCX sin document.xml');

  final headingLevels = _headingStyles(readXml('word/styles.xml'));
  final rels = _relationships(readXml('word/_rels/document.xml.rels'));
  final builder = BlockBuilder();

  final body = document.descendants.whereType<XmlElement>().firstWhere(
    (e) => e.name.local == 'body',
  );

  for (final paragraph in body.descendants.whereType<XmlElement>().where(
    (e) => e.name.local == 'p' && !_insideFallback(e),
  )) {
    final pPr = _child(paragraph, 'pPr');
    final styleId = _attr(_child(pPr, 'pStyle'), 'val');
    final outline = int.tryParse(_attr(_child(pPr, 'outlineLvl'), 'val') ?? '');
    final headingLevel =
        headingLevels[styleId] ?? (outline != null ? outline + 1 : null);
    final isList = _child(pPr, 'numPr') != null;
    final centered = _attr(_child(pPr, 'jc'), 'val') == 'center';
    final kind = isList
        ? ParagraphKind.listItem
        : centered
        ? ParagraphKind.center
        : ParagraphKind.normal;

    final images = <Uint8List>[];
    for (final run in paragraph.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'r' && !_insideFallback(e),
    )) {
      // Evita runs anidados (p. ej. dentro de cuadros de texto de otro párrafo).
      if (_nearestParagraph(run) != paragraph) continue;
      final rPr = _child(run, 'rPr');
      final bold = _isOn(_child(rPr, 'b'));
      final italic = _isOn(_child(rPr, 'i'));
      for (final node in run.childElements) {
        switch (node.name.local) {
          case 't':
            builder.addText(node.innerText, bold: bold, italic: italic);
          case 'tab':
            builder.addText(' ', bold: bold, italic: italic);
          case 'br' || 'cr':
            builder.addText('\n', bold: bold, italic: italic);
          case 'drawing' || 'pict':
            for (final blip in node.descendants.whereType<XmlElement>().where(
              (e) => e.name.local == 'blip' || e.name.local == 'imagedata',
            )) {
              final relId = blip.attributes
                  .where((a) => a.name.local == 'embed' || a.name.local == 'id')
                  .map((a) => a.value)
                  .firstOrNull;
              final target = rels[relId];
              if (target == null) continue;
              final path = p.url.normalize(p.url.join('word', target));
              final data = archive.findFile(path)?.readBytes();
              if (data != null && data.isNotEmpty) images.add(data);
            }
        }
      }
    }

    if (headingLevel != null && headingLevel <= 6) {
      builder.flush(headingLevel: headingLevel);
    } else {
      builder.flush(kind: kind);
    }
    for (final image in images) {
      builder.addBlock(ImageBlock(image));
    }
  }

  return ReaderDocument(
    builder.blocks,
    tocFromHeadings(builder.blocks, maxLevel: 3),
  );
}

XmlElement? _child(XmlElement? parent, String local) =>
    parent?.childElements.where((e) => e.name.local == local).firstOrNull;

String? _attr(XmlElement? element, String local) => element?.attributes
    .where((a) => a.name.local == local)
    .map((a) => a.value)
    .firstOrNull;

/// `<w:b/>` activa; `<w:b w:val="0"/>` o `false` desactiva.
bool _isOn(XmlElement? element) {
  if (element == null) return false;
  final val = _attr(element, 'val');
  return val == null || !(val == '0' || val == 'false' || val == 'none');
}

bool _insideFallback(XmlElement e) =>
    e.ancestors.whereType<XmlElement>().any((a) => a.name.local == 'Fallback');

XmlElement? _nearestParagraph(XmlElement e) => e.ancestors
    .whereType<XmlElement>()
    .where((a) => a.name.local == 'p')
    .firstOrNull;

/// styleId → nivel de título, a partir de los nombres internos de estilo
/// (`heading 1`, `Title`…), que no cambian con el idioma de Word.
Map<String?, int> _headingStyles(XmlDocument? styles) {
  final map = <String?, int>{};
  if (styles == null) return map;
  for (final style in styles.descendants.whereType<XmlElement>().where(
    (e) => e.name.local == 'style',
  )) {
    final id = _attr(style, 'styleId');
    final name = (_attr(_child(style, 'name'), 'val') ?? '').toLowerCase();
    final outline = int.tryParse(
      _attr(_child(_child(style, 'pPr'), 'outlineLvl'), 'val') ?? '',
    );
    final heading = RegExp(r'^heading (\d)$').firstMatch(name);
    if (name == 'title') {
      map[id] = 1;
    } else if (name == 'subtitle') {
      map[id] = 2;
    } else if (heading != null) {
      map[id] = int.parse(heading.group(1)!);
    } else if (outline != null && outline < 6) {
      map[id] = outline + 1;
    }
  }
  return map;
}

Map<String?, String> _relationships(XmlDocument? rels) => {
  if (rels != null)
    for (final rel in rels.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'Relationship',
    ))
      rel.getAttribute('Id'): rel.getAttribute('Target') ?? '',
};
