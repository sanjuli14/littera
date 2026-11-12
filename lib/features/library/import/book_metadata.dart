import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Datos extraídos de un archivo al importarlo.
class BookMetadata {
  const BookMetadata({this.title, this.author, this.coverBytes});

  final String? title;
  final String? author;
  final Uint8List? coverBytes;
}

/// Título legible a partir del nombre de archivo:
/// `el_nombre-del_viento.epub` → `El nombre del viento`.
String titleFromFileName(String fileName) {
  final name = p.basename(fileName);
  final dot = name.lastIndexOf('.');
  final base = (dot >= 0 ? name.substring(0, dot) : name)
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.isEmpty) return 'Sin título';
  return base[0].toUpperCase() + base.substring(1);
}

Iterable<XmlElement> _byLocalName(XmlNode node, String local) => node
    .descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local);

String? _firstText(XmlNode node, String local) {
  for (final e in _byLocalName(node, local)) {
    final text = e.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

XmlDocument? _parseXml(Archive archive, String path) {
  final file = archive.findFile(path);
  final bytes = file?.readBytes();
  if (bytes == null) return null;
  try {
    return XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
  } on XmlException {
    return null;
  }
}

/// Lee título, autor y carátula de un EPUB (2 y 3).
BookMetadata parseEpubMetadata(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return const BookMetadata();
  }

  final container = _parseXml(archive, 'META-INF/container.xml');
  final opfPath = container == null
      ? null
      : _byLocalName(container, 'rootfile')
            .map((e) => e.getAttribute('full-path'))
            .whereType<String>()
            .firstOrNull;
  if (opfPath == null) return const BookMetadata();

  final opf = _parseXml(archive, opfPath);
  if (opf == null) return const BookMetadata();

  final title = _firstText(opf, 'title');
  final author = _firstText(opf, 'creator');

  // Carátula: EPUB3 (properties="cover-image") → EPUB2 (<meta name="cover">)
  // → cualquier imagen cuyo id/href contenga "cover".
  final items = _byLocalName(opf, 'item').toList();
  bool isImage(XmlElement e) =>
      (e.getAttribute('media-type') ?? '').startsWith('image/');

  XmlElement? coverItem = items.where((e) {
    final props = e.getAttribute('properties') ?? '';
    return props.split(' ').contains('cover-image');
  }).firstOrNull;

  if (coverItem == null) {
    final coverId = _byLocalName(opf, 'meta')
        .where((e) => e.getAttribute('name') == 'cover')
        .map((e) => e.getAttribute('content'))
        .whereType<String>()
        .firstOrNull;
    if (coverId != null) {
      coverItem = items
          .where((e) => e.getAttribute('id') == coverId && isImage(e))
          .firstOrNull;
    }
  }

  coverItem ??= items.where((e) {
    final id = (e.getAttribute('id') ?? '').toLowerCase();
    final href = (e.getAttribute('href') ?? '').toLowerCase();
    return isImage(e) && (id.contains('cover') || href.contains('cover'));
  }).firstOrNull;

  Uint8List? cover;
  final href = coverItem?.getAttribute('href');
  if (href != null) {
    final path = p.url.normalize(
      p.url.join(p.url.dirname(opfPath), Uri.decodeFull(href)),
    );
    cover = archive.findFile(path)?.readBytes();
  }

  return BookMetadata(title: title, author: author, coverBytes: cover);
}

/// Lee título y autor de las propiedades de un DOCX (`docProps/core.xml`).
BookMetadata parseDocxMetadata(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final core = _parseXml(archive, 'docProps/core.xml');
    if (core == null) return const BookMetadata();
    return BookMetadata(
      title: _firstText(core, 'title'),
      author: _firstText(core, 'creator'),
    );
  } catch (_) {
    return const BookMetadata();
  }
}

/// `true` si los bytes parecen un ZIP (EPUB y DOCX lo son).
bool looksLikeZip(Uint8List bytes) =>
    bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

/// `true` si los bytes parecen un PDF.
bool looksLikePdf(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;
