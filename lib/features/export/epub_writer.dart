import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../reader/document/reader_document.dart';
import 'manuscript_compiler.dart';

/// Escapa texto para XHTML.
String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _runsToHtml(List<TextRun> runs) {
  final out = StringBuffer();
  for (final r in runs) {
    var text = xmlEscape(r.text).replaceAll('\n', '<br/>');
    if (r.italic) text = '<em>$text</em>';
    if (r.bold) text = '<strong>$text</strong>';
    out.write(text);
  }
  return out.toString();
}

/// Bloques → XHTML. Agrupa los elementos de lista consecutivos en `<ul>`.
String blocksToXhtml(List<DocBlock> blocks) {
  final out = StringBuffer();
  var inList = false;
  for (final block in blocks) {
    final isListItem =
        block is ParagraphBlock && block.kind == ParagraphKind.listItem;
    if (inList && !isListItem) {
      out.writeln('</ul>');
      inList = false;
    }
    switch (block) {
      case HeadingBlock(:final level, :final runs):
        out.writeln('<h$level>${_runsToHtml(runs)}</h$level>');
      case ParagraphBlock(:final kind, :final runs):
        final html = _runsToHtml(runs);
        switch (kind) {
          case ParagraphKind.listItem:
            if (!inList) {
              out.writeln('<ul>');
              inList = true;
            }
            out.writeln('<li>$html</li>');
          case ParagraphKind.quote:
            out.writeln('<blockquote><p>$html</p></blockquote>');
          case ParagraphKind.center:
            out.writeln('<p class="center">$html</p>');
          case ParagraphKind.preformatted:
            out.writeln('<pre>$html</pre>');
          case ParagraphKind.normal:
            out.writeln('<p>$html</p>');
        }
      case SeparatorBlock():
        out.writeln('<hr/>');
      case ImageBlock():
        break; // el editor no inserta imágenes
    }
  }
  if (inList) out.writeln('</ul>');
  return out.toString();
}

String _page(String title, String body, {String type = ''}) =>
    '''
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="es" lang="es">
<head>
  <meta charset="utf-8"/>
  <title>${xmlEscape(title)}</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body${type.isEmpty ? '' : ' epub:type="$type"'}>
$body
</body>
</html>
''';

const _css = '''
body { font-family: serif; line-height: 1.5; margin: 0 5%; }
h1 { text-align: center; margin: 2em 0 1.5em; font-size: 1.6em; page-break-before: always; }
h2, h3, h4, h5, h6 { margin: 1.5em 0 0.8em; }
p { text-indent: 1.5em; margin: 0 0 0.3em; text-align: justify; }
p.center { text-align: center; text-indent: 0; }
blockquote { margin: 1em 2em; font-style: italic; }
blockquote p { text-indent: 0; }
pre { white-space: pre-wrap; font-family: monospace; }
.title-page { text-align: center; margin-top: 30%; }
.title-page h1 { page-break-before: auto; font-size: 2em; margin-bottom: 0.5em; }
.title-page .author { font-size: 1.2em; margin-top: 1em; text-indent: 0; text-align: center; }
.cover { margin: 0; padding: 0; text-align: center; }
.cover img { max-width: 100%; max-height: 100%; }
''';

/// Genera un EPUB 3 (con toc.ncx para lectores antiguos).
///
/// [coverJpeg] es la carátula en JPEG; si es `null` el libro empieza en la
/// portada de texto. [modified] fija la fecha (útil en tests).
Uint8List writeEpub(
  CompiledBook book, {
  Uint8List? coverJpeg,
  DateTime? modified,
}) {
  final archive = Archive();
  void add(String name, String content) =>
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));

  // "mimetype" debe ser el primer archivo y sin comprimir.
  archive.addFile(
    ArchiveFile.bytes('mimetype', utf8.encode('application/epub+zip'))
      ..compression = CompressionType.none,
  );
  add(
    'META-INF/container.xml',
    '<?xml version="1.0" encoding="utf-8"?>\n'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add('OEBPS/style.css', _css);

  final title = xmlEscape(book.title);
  final author = xmlEscape(book.author);
  final uid = 'urn:uuid:${book.id}';
  final when = (modified ?? DateTime.now()).toUtc();
  final stamp = '${when.toIso8601String().split('.').first}Z';

  // Páginas en orden de lectura: (id, archivo, título para el índice).
  final spine = <(String, String, String?)>[];

  if (coverJpeg != null) {
    archive.addFile(
      ArchiveFile.bytes('OEBPS/images/cover.jpg', coverJpeg)
        ..compression = CompressionType.none,
    );
    add(
      'OEBPS/cover.xhtml',
      _page(
        book.title,
        '<div class="cover"><img src="images/cover.jpg" alt="$title"/></div>',
        type: 'cover',
      ),
    );
    spine.add(('cover', 'cover.xhtml', null));
  }

  add(
    'OEBPS/title.xhtml',
    _page(
      book.title,
      '<div class="title-page"><h1>$title</h1>'
      '${author.isEmpty ? '' : '<p class="author">$author</p>'}</div>',
      type: 'titlepage',
    ),
  );
  spine.add(('titlepage', 'title.xhtml', null));

  for (var i = 0; i < book.chapters.length; i++) {
    final c = book.chapters[i];
    final file = 'chapter-${i + 1}.xhtml';
    add(
      'OEBPS/$file',
      _page(
        c.title,
        '<section epub:type="chapter">\n<h1>${xmlEscape(c.title)}</h1>\n'
        '${blocksToXhtml(c.blocks)}</section>',
      ),
    );
    spine.add(('ch${i + 1}', file, c.title));
  }

  final tocEntries = spine.where((s) => s.$3 != null).toList();

  add(
    'OEBPS/nav.xhtml',
    _page(
      'Índice',
      '<nav epub:type="toc" id="toc"><h1>Índice</h1><ol>\n'
          '${tocEntries.map((e) => '<li><a href="${e.$2}">${xmlEscape(e.$3!)}</a></li>').join('\n')}'
          '\n</ol></nav>',
    ),
  );

  add(
    'OEBPS/toc.ncx',
    '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
        '<head><meta name="dtb:uid" content="$uid"/></head>'
        '<docTitle><text>$title</text></docTitle><navMap>'
        '${[for (var i = 0; i < tocEntries.length; i++) '<navPoint id="np${i + 1}" playOrder="${i + 1}"><navLabel><text>${xmlEscape(tocEntries[i].$3!)}</text></navLabel><content src="${tocEntries[i].$2}"/></navPoint>'].join()}'
        '</navMap></ncx>',
  );

  final manifest = StringBuffer()
    ..write(
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    )
    ..write(
      '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    )
    ..write('<item id="css" href="style.css" media-type="text/css"/>');
  if (coverJpeg != null) {
    manifest.write(
      '<item id="cover-image" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>',
    );
  }
  for (final (id, file, _) in spine) {
    manifest.write(
      '<item id="$id" href="$file" media-type="application/xhtml+xml"/>',
    );
  }

  add(
    'OEBPS/content.opf',
    '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="es">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="bookid">$uid</dc:identifier>'
        '<dc:title>$title</dc:title>'
        '${author.isEmpty ? '' : '<dc:creator>$author</dc:creator>'}'
        '<dc:language>es</dc:language>'
        '${book.synopsis.isEmpty ? '' : '<dc:description>${xmlEscape(book.synopsis)}</dc:description>'}'
        '<meta property="dcterms:modified">$stamp</meta>'
        '${coverJpeg != null ? '<meta name="cover" content="cover-image"/>' : ''}'
        '</metadata>'
        '<manifest>$manifest</manifest>'
        '<spine toc="ncx">${spine.map((s) => '<itemref idref="${s.$1}"/>').join()}</spine>'
        '</package>',
  );

  return ZipEncoder().encodeBytes(archive);
}
