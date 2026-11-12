import 'package:flutter_test/flutter_test.dart';
import 'package:littera/features/reader/document/docx_parser.dart';
import 'package:littera/features/reader/document/epub_parser.dart';
import 'package:littera/features/reader/document/reader_document.dart';

import 'helpers.dart';

const _container =
    '<?xml version="1.0"?><container version="1.0" '
    'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

String _xhtml(String body) =>
    '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml">'
    '<head><title>x</title><style>p{}</style></head><body>$body</body></html>';

void main() {
  group('EPUB', () {
    final epub3 = buildZip(
      {
        'mimetype': 'application/epub+zip',
        'META-INF/container.xml': _container,
        'OEBPS/content.opf':
            '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
            '<metadata/><manifest>'
            '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
            '<item id="c1" href="text/cap%201.xhtml" media-type="application/xhtml+xml"/>'
            '<item id="c2" href="text/cap2.xhtml" media-type="application/xhtml+xml"/>'
            '<item id="img" href="img/foto.png" media-type="image/png"/>'
            '</manifest><spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>',
        'OEBPS/nav.xhtml': _xhtml(
          '<nav epub:type="toc"><ol>'
          '<li><a href="text/cap%201.xhtml">Uno</a></li>'
          '<li><a href="text/cap2.xhtml">Dos</a><ol>'
          '<li><a href="text/cap2.xhtml#sec">Sección</a></li></ol></li>'
          '</ol></nav>',
        ),
        'OEBPS/text/cap 1.xhtml': _xhtml(
          '<h1>Capítulo   uno</h1>'
          '<p>Hola <b>mundo</b> y <em>bienvenido</em>.</p>'
          '<p>Línea uno<br/>línea dos</p>'
          '<div><div>Texto en div anidado</div></div>'
          '<p>   </p>'
          '<img src="../img/foto.png" alt="Una foto"/>'
          '<script>alert(1)</script>',
        ),
        'OEBPS/text/cap2.xhtml': _xhtml(
          '<h2>Capítulo dos</h2><p>Antes</p><hr/>'
          '<h3 id="sec">Sección</h3>'
          '<blockquote><p>Una cita</p></blockquote>'
          '<ul><li>Primero</li><li>Segundo</li></ul>'
          '<p style="text-align: center">Centrado</p>',
        ),
      },
      binary: {'OEBPS/img/foto.png': pngBytes(width: 10, height: 10)},
    );

    late ReaderDocument doc;
    setUpAll(() => doc = parseEpub(epub3));

    test('títulos, párrafos y estilos en orden', () {
      final b = doc.blocks;
      expect(b[0], isA<HeadingBlock>());
      expect((b[0] as HeadingBlock).text, 'Capítulo uno');
      expect((b[0] as HeadingBlock).level, 1);

      final p1 = b[1] as ParagraphBlock;
      expect(p1.text, 'Hola mundo y bienvenido.');
      expect(p1.runs.where((r) => r.bold).single.text, 'mundo');
      expect(p1.runs.where((r) => r.italic).single.text, 'bienvenido');

      expect((b[2] as ParagraphBlock).text, 'Línea uno\nlínea dos');
      expect((b[3] as ParagraphBlock).text, 'Texto en div anidado');
    });

    test('ignora párrafos vacíos y scripts; incluye imágenes', () {
      final texts = doc.blocks.whereType<ParagraphBlock>().map((p) => p.text);
      expect(texts.any((t) => t.contains('alert')), isFalse);
      final image = doc.blocks[4] as ImageBlock;
      expect(image.alt, 'Una foto');
      expect(image.bytes, isNotEmpty);
    });

    test('separadores, citas, listas y centrado', () {
      expect(doc.blocks.whereType<SeparatorBlock>(), hasLength(1));
      final kinds = {
        for (final p in doc.blocks.whereType<ParagraphBlock>()) p.text: p.kind,
      };
      expect(kinds['Una cita'], ParagraphKind.quote);
      expect(kinds['Primero'], ParagraphKind.listItem);
      expect(kinds['Segundo'], ParagraphKind.listItem);
      expect(kinds['Centrado'], ParagraphKind.center);
    });

    test('índice desde nav, con anclas y niveles', () {
      expect(doc.toc.map((e) => e.title), ['Uno', 'Dos', 'Sección']);
      expect(doc.toc[0].blockIndex, 0);
      final dos = doc.blocks[doc.toc[1].blockIndex] as HeadingBlock;
      expect(dos.text, 'Capítulo dos');
      final sec = doc.blocks[doc.toc[2].blockIndex] as HeadingBlock;
      expect(sec.text, 'Sección');
      expect(doc.toc[2].level, 2);
      expect(doc.tocEntryFor(doc.toc[2].blockIndex + 1)?.title, 'Sección');
    });

    test('EPUB 2: índice desde toc.ncx', () {
      final epub2 = buildZip({
        'META-INF/container.xml': _container,
        'OEBPS/content.opf':
            '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"><metadata/>'
            '<manifest><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
            '<item id="a" href="a.html" media-type="application/xhtml+xml"/>'
            '<item id="b" href="b.html" media-type="application/xhtml+xml"/></manifest>'
            '<spine toc="ncx"><itemref idref="a"/><itemref idref="b"/></spine></package>',
        'OEBPS/toc.ncx':
            '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>'
            '<navPoint id="n1"><navLabel><text>Prólogo</text></navLabel><content src="a.html"/></navPoint>'
            '<navPoint id="n2"><navLabel><text>Final</text></navLabel><content src="b.html"/></navPoint>'
            '</navMap></ncx>',
        'OEBPS/a.html': '<html><body><p>Inicio</p><p>Más</p></body></html>',
        'OEBPS/b.html': '<html><body><p>Fin</p></body></html>',
      });
      final d = parseEpub(epub2);
      expect(d.toc.map((e) => e.title), ['Prólogo', 'Final']);
      expect((d.blocks[d.toc[1].blockIndex] as ParagraphBlock).text, 'Fin');
    });

    test('sin índice: usa los títulos', () {
      final d = parseEpub(buildEpub(withCover: false));
      expect(d.blocks, isNotEmpty);
      final noToc = buildZip({
        'META-INF/container.xml': _container,
        'OEBPS/content.opf':
            '<package xmlns="http://www.idpf.org/2007/opf"><metadata/><manifest>'
            '<item id="a" href="a.html" media-type="application/xhtml+xml"/></manifest>'
            '<spine><itemref idref="a"/></spine></package>',
        'OEBPS/a.html': '<html><body><h1>Uno</h1><p>x</p><h2>Dos</h2><h4>No</h4></body></html>',
      });
      expect(parseEpub(noToc).toc.map((e) => e.title), ['Uno', 'Dos']);
    });
  });

  group('DOCX', () {
    const w =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"';

    final docx = buildZip(
      {
        'word/styles.xml':
            '<w:styles $w>'
            '<w:style w:styleId="Ttulo1"><w:name w:val="heading 1"/></w:style>'
            '<w:style w:styleId="Ttulo"><w:name w:val="Title"/></w:style>'
            '</w:styles>',
        'word/_rels/document.xml.rels': '<Relationships><Relationship Id="rId5" Target="media/image1.png"/></Relationships>',
        'word/document.xml':
            '<w:document $w><w:body>'
            '<w:p><w:pPr><w:pStyle w:val="Ttulo"/></w:pPr><w:r><w:t>Mi libro</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:pStyle w:val="Ttulo1"/></w:pPr><w:r><w:t>Capítulo 1</w:t></w:r></w:p>'
            '<w:p><w:r><w:t xml:space="preserve">Era </w:t></w:r>'
            '<w:r><w:rPr><w:b/></w:rPr><w:t>una</w:t></w:r>'
            '<w:r><w:rPr><w:i/><w:b w:val="0"/></w:rPr><w:t xml:space="preserve"> vez</w:t></w:r></w:p>'
            '<w:p/>'
            '<w:p><w:pPr><w:numPr/></w:pPr><w:r><w:t>Elemento</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>* * *</w:t></w:r></w:p>'
            '<w:p><w:r><w:drawing><a:blip r:embed="rId5"/></w:drawing></w:r></w:p>'
            '<w:p><w:r><mc:AlternateContent><mc:Choice><w:t>A</w:t></mc:Choice>'
            '<mc:Fallback><w:p><w:r><w:t>Duplicado</w:t></w:r></w:p></mc:Fallback>'
            '</mc:AlternateContent></w:r></w:p>'
            '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Celda</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
            '</w:body></w:document>',
      },
      binary: {'word/media/image1.png': pngBytes(width: 8, height: 8)},
    );

    test('títulos por nombre de estilo, aunque Word esté en español', () {
      final d = parseDocx(docx);
      final h = d.blocks.whereType<HeadingBlock>().toList();
      expect(h.map((e) => e.text), ['Mi libro', 'Capítulo 1']);
      expect(h.every((e) => e.level == 1), isTrue);
      expect(d.toc.map((e) => e.title), ['Mi libro', 'Capítulo 1']);
    });

    test('negrita, cursiva, listas, centrado, imágenes y tablas', () {
      final d = parseDocx(docx);
      final paragraphs = d.blocks.whereType<ParagraphBlock>().toList();
      final first = paragraphs.first;
      expect(first.text, 'Era una vez');
      expect(first.runs.singleWhere((r) => r.bold).text, 'una');
      expect(first.runs.singleWhere((r) => r.italic).text, ' vez');

      final byText = {for (final p in paragraphs) p.text: p.kind};
      expect(byText['Elemento'], ParagraphKind.listItem);
      expect(byText['* * *'], ParagraphKind.center);
      expect(byText.containsKey('Celda'), isTrue);
      expect(byText.containsKey('Duplicado'), isFalse);
      expect(d.blocks.whereType<ImageBlock>(), hasLength(1));
    });
  });
}
