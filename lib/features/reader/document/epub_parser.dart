import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'reader_document.dart';

/// Convierte un EPUB (2 o 3) en un [ReaderDocument].
ReaderDocument parseEpub(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  String? readText(String path) {
    final data = archive.findFile(path)?.readBytes();
    return data == null ? null : utf8.decode(data, allowMalformed: true);
  }

  final container = readText('META-INF/container.xml');
  if (container == null) throw const FormatException('EPUB sin container.xml');
  final opfPath = _elements(
    XmlDocument.parse(container),
    'rootfile',
  ).map((e) => e.getAttribute('full-path')).whereType<String>().first;
  final opfDir = p.url.dirname(opfPath);
  final opf = XmlDocument.parse(readText(opfPath)!);

  // Manifiesto: id → (ruta, tipo, propiedades).
  final manifest = <String, ({String path, String type, String props})>{};
  for (final item in _elements(opf, 'item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = (
      path: _resolve(opfDir, href),
      type: item.getAttribute('media-type') ?? '',
      props: item.getAttribute('properties') ?? '',
    );
  }

  final builder = BlockBuilder();
  final fileStart = <String, int>{};

  final spine = _elements(opf, 'spine').firstOrNull;
  for (final ref
      in spine == null ? <XmlElement>[] : _elements(spine, 'itemref')) {
    final item = manifest[ref.getAttribute('idref')];
    if (item == null) continue;
    final source = readText(item.path);
    if (source == null) continue;

    builder.flush();
    fileStart[item.path] = builder.blocks.length;
    final document = html.parse(source);
    final body = document.body;
    if (body == null) continue;
    _HtmlWalker(builder, archive, item.path).walk(body);
    builder.flush();
  }

  // Índice: nav (EPUB3) → NCX (EPUB2) → títulos.
  var toc = <TocEntry>[];
  int? resolveTarget(String baseDir, String href) {
    final hashIdx = href.indexOf('#');
    final file = hashIdx >= 0 ? href.substring(0, hashIdx) : href;
    final fragment = hashIdx >= 0 ? href.substring(hashIdx + 1) : null;
    final path = file.isEmpty ? null : _resolve(baseDir, file);
    if (path == null) return null;
    if (fragment != null && fragment.isNotEmpty) {
      final anchored = builder.anchors['$path#$fragment'];
      if (anchored != null) return anchored;
    }
    return fileStart[path];
  }

  final navItem = manifest.values
      .where((i) => i.props.split(' ').contains('nav'))
      .firstOrNull;
  if (navItem != null) {
    final navSource = readText(navItem.path);
    if (navSource != null) {
      toc = _parseNav(
        html.parse(navSource),
        (href) => resolveTarget(p.url.dirname(navItem.path), href),
      );
    }
  }
  if (toc.isEmpty) {
    final ncxId = spine?.getAttribute('toc');
    final ncxItem =
        manifest[ncxId] ??
        manifest.values
            .where((i) => i.type == 'application/x-dtbncx+xml')
            .firstOrNull;
    final ncxSource = ncxItem == null ? null : readText(ncxItem.path);
    if (ncxSource != null) {
      toc = _parseNcx(
        XmlDocument.parse(ncxSource),
        (href) => resolveTarget(p.url.dirname(ncxItem!.path), href),
      );
    }
  }
  if (toc.isEmpty) toc = tocFromHeadings(builder.blocks);

  final blockCount = builder.blocks.length;
  toc = toc.where((e) => e.blockIndex < blockCount).toList()
    ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
  return ReaderDocument(builder.blocks, toc);
}

Iterable<XmlElement> _elements(XmlNode node, String local) => node.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local);

String _resolve(String baseDir, String href) {
  String decoded;
  try {
    decoded = Uri.decodeFull(href);
  } catch (_) {
    decoded = href;
  }
  return p.url.normalize(p.url.join(baseDir, decoded));
}

List<TocEntry> _parseNav(dom.Document doc, int? Function(String) resolve) {
  final navs = doc.getElementsByTagName('nav');
  final tocNav =
      navs
          .where(
            (n) => (n.attributes['epub:type'] ?? n.attributes['type'] ?? '')
                .contains('toc'),
          )
          .firstOrNull ??
      navs.firstOrNull;
  if (tocNav == null) return const [];

  final entries = <TocEntry>[];
  void visitList(dom.Element list, int level) {
    for (final li in list.children.where((c) => c.localName == 'li')) {
      final link = li.children
          .where((c) => c.localName == 'a' || c.localName == 'span')
          .firstOrNull;
      final href = link?.attributes['href'];
      final title = link?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (href != null && title.isNotEmpty) {
        final index = resolve(href);
        if (index != null) entries.add(TocEntry(title, index, level: level));
      }
      for (final sub in li.children.where((c) => c.localName == 'ol')) {
        visitList(sub, level + 1);
      }
    }
  }

  final root = tocNav.children.where((c) => c.localName == 'ol').firstOrNull;
  if (root != null) visitList(root, 1);
  return entries;
}

List<TocEntry> _parseNcx(XmlDocument doc, int? Function(String) resolve) {
  final entries = <TocEntry>[];
  void visit(XmlElement parent, int level) {
    for (final point in parent.childElements.where(
      (e) => e.name.local == 'navPoint',
    )) {
      final label =
          _elements(point, 'text').firstOrNull?.innerText.trim() ?? '';
      final src = point.childElements
          .where((e) => e.name.local == 'content')
          .firstOrNull
          ?.getAttribute('src');
      if (src != null && label.isNotEmpty) {
        final index = resolve(src);
        if (index != null) entries.add(TocEntry(label, index, level: level));
      }
      visit(point, level + 1);
    }
  }

  final navMap = _elements(doc, 'navMap').firstOrNull;
  if (navMap != null) visit(navMap, 1);
  return entries;
}

const _skipTags = {'script', 'style', 'head', 'title', 'noscript', 'nav'};
const _blockTags = {
  'p', 'div', 'section', 'article', 'header', 'footer', 'aside', 'main', //
  'figure', 'figcaption', 'dd', 'dt', 'dl', 'ul', 'ol', 'table', 'tr', //
  'td', 'th', 'tbody', 'thead', 'caption', 'center', 'address',
};

/// Recorre el HTML de un capítulo y va generando bloques.
class _HtmlWalker {
  _HtmlWalker(this.builder, this.archive, this.filePath);

  final BlockBuilder builder;
  final Archive archive;
  final String filePath;

  void walk(
    dom.Node node, {
    bool bold = false,
    bool italic = false,
    ParagraphKind kind = ParagraphKind.normal,
  }) {
    if (node is dom.Text) {
      builder.addText(node.text, bold: bold, italic: italic);
      return;
    }
    if (node is! dom.Element) {
      for (final child in node.nodes) {
        walk(child, bold: bold, italic: italic, kind: kind);
      }
      return;
    }

    final tag = node.localName ?? '';
    if (_skipTags.contains(tag)) return;

    final id = node.id;
    if (id.isNotEmpty) builder.addAnchor('$filePath#$id');

    void children({bool? b, bool? i, ParagraphKind? k}) {
      for (final child in node.nodes) {
        walk(child, bold: b ?? bold, italic: i ?? italic, kind: k ?? kind);
      }
    }

    switch (tag) {
      case 'br':
        builder.addText('\n', bold: bold, italic: italic);
      case 'img':
        _addImage(node.attributes['src'], node.attributes['alt'], kind);
      case 'image': // <svg><image xlink:href>
        _addImage(
          node.attributes['xlink:href'] ?? node.attributes['href'],
          null,
          kind,
        );
      case 'hr':
        builder.flush(kind: kind);
        builder.addBlock(const SeparatorBlock());
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        builder.flush(kind: kind);
        children(b: false, i: false);
        builder.flush(headingLevel: int.parse(tag.substring(1)));
      case 'blockquote':
        builder.flush(kind: kind);
        children(k: ParagraphKind.quote);
        builder.flush(kind: ParagraphKind.quote);
      case 'li':
        builder.flush(kind: kind);
        children(k: ParagraphKind.listItem);
        builder.flush(kind: ParagraphKind.listItem);
      case 'pre':
        builder.flush(kind: kind);
        children(k: ParagraphKind.preformatted);
        builder.flush(kind: ParagraphKind.preformatted);
      case 'b' || 'strong':
        children(b: true);
      case 'i' || 'em' || 'cite' || 'var' || 'dfn':
        children(i: true);
      default:
        if (_blockTags.contains(tag) || tag == 'body') {
          final style = (node.attributes['style'] ?? '').replaceAll(' ', '');
          final cls = node.attributes['class'] ?? '';
          final center =
              tag == 'center' ||
              style.contains('text-align:center') ||
              RegExp(r'\b(center|centered|centrado)\b').hasMatch(cls);
          final k = center && kind == ParagraphKind.normal
              ? ParagraphKind.center
              : kind;
          builder.flush(kind: kind);
          children(k: k);
          builder.flush(kind: k);
        } else {
          children(); // inline: a, span, sup, small…
        }
    }
  }

  void _addImage(String? src, String? alt, ParagraphKind kind) {
    if (src == null || src.startsWith('data:') || src.startsWith('http')) {
      return;
    }
    final path = _resolve(p.url.dirname(filePath), src.split('#').first);
    final bytes = archive.findFile(path)?.readBytes();
    if (bytes == null || bytes.isEmpty) return;
    builder.flush(kind: kind);
    builder.addBlock(ImageBlock(bytes, alt: alt));
  }
}
