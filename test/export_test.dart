import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littera/data/models/manuscript.dart';
import 'package:littera/features/export/epub_writer.dart';
import 'package:littera/features/export/manuscript_compiler.dart';
import 'package:littera/features/export/pdf_writer.dart';
import 'package:littera/features/library/import/book_metadata.dart';
import 'package:littera/features/reader/document/epub_parser.dart';
import 'package:littera/features/reader/document/reader_document.dart';

import 'helpers.dart';

String delta(List<Map<String, Object?>> ops) => jsonEncode(ops);

final now = DateTime(2026, 11, 12);

Manuscript manuscript({String title = 'El faro', String author = 'Ana Ruiz'}) =>
    Manuscript(
      id: '3f2a9c1e-0000-4000-8000-000000000001',
      title: title,
      author: author,
      synopsis: 'Una farera & su secreto',
      createdAt: now,
      updatedAt: now,
    );

Chapter chapter(int order, String title, String content) => Chapter(
  id: 'c$order',
  manuscriptId: 'm',
  title: title,
  order: order,
  content: content,
  createdAt: now,
  updatedAt: now,
);

final richChapter = delta([
  {'insert': 'Primer párrafo con '},
  {
    'insert': 'negrita',
    'attributes': {'bold': true},
  },
  {'insert': ' y '},
  {
    'insert': 'cursiva',
    'attributes': {'italic': true},
  },
  {'insert': '.\nUn título interno'},
  {
    'insert': '\n',
    'attributes': {'header': 1},
  },
  {'insert': 'Una cita <con> símbolos & "comillas"'},
  {
    'insert': '\n',
    'attributes': {'blockquote': true},
  },
  {'insert': 'Uno'},
  {
    'insert': '\n',
    'attributes': {'list': 'bullet'},
  },
  {'insert': 'Dos'},
  {
    'insert': '\n',
    'attributes': {'list': 'bullet'},
  },
  {'insert': 'Primero'},
  {
    'insert': '\n',
    'attributes': {'list': 'ordered'},
  },
  {'insert': 'Segundo'},
  {
    'insert': '\n',
    'attributes': {'list': 'ordered'},
  },
  {'insert': '* * *'},
  {
    'insert': '\n',
    'attributes': {'align': 'center'},
  },
  {'insert': '\n\nÚltimo párrafo.\n'},
]);

void main() {
  group('del editor a bloques', () {
    test('estilos de línea y de texto', () {
      final blocks = deltaToBlocks(richChapter);
      final p0 = blocks[0] as ParagraphBlock;
      expect(p0.text, 'Primer párrafo con negrita y cursiva.');
      expect(p0.runs.singleWhere((r) => r.bold).text, 'negrita');
      expect(p0.runs.singleWhere((r) => r.italic).text, 'cursiva');

      final h = blocks[1] as HeadingBlock;
      expect(h.text, 'Un título interno');
      expect(h.level, 2); // debajo del título de capítulo

      final kinds = {
        for (final b in blocks.whereType<ParagraphBlock>()) b.text: b.kind,
      };
      expect(
        kinds['Una cita <con> símbolos & "comillas"'],
        ParagraphKind.quote,
      );
      expect(kinds['Uno'], ParagraphKind.listItem);
      expect(kinds['1. Primero'], ParagraphKind.normal);
      expect(kinds['2. Segundo'], ParagraphKind.normal);
      expect(kinds['* * *'], ParagraphKind.center);
      expect(blocks.last, isA<ParagraphBlock>());
      expect((blocks.last as ParagraphBlock).text, 'Último párrafo.');
    });

    test('las líneas vacías no generan párrafos', () {
      expect(
        deltaToBlocks(
          delta([
            {'insert': '\n\n\n'},
          ]),
        ),
        isEmpty,
      );
      expect(deltaToBlocks(''), isEmpty);
    });
  });

  test('compilar omite capítulos vacíos y respeta el orden', () {
    final book = compileManuscript(manuscript(), [
      chapter(
        2,
        'Final',
        delta([
          {'insert': 'Fin.\n'},
        ]),
      ),
      chapter(
        0,
        'Inicio',
        delta([
          {'insert': 'Hola.\n'},
        ]),
      ),
      chapter(1, 'Borrador vacío', ''),
    ]);
    expect(book.chapters.map((c) => c.title), ['Inicio', 'Final']);
  });

  test('nombres de archivo seguros', () {
    expect(
      exportFileName('El faro (borrador)', 'epub'),
      'el-faro-borrador.epub',
    );
    expect(exportFileName('Niño ¿y qué?', 'pdf'), 'nino-y-que.pdf');
    expect(exportFileName('¡¡!!', 'pdf'), 'obra.pdf');
  });

  group('EPUB', () {
    final book = compileManuscript(manuscript(), [
      chapter(0, 'Capítulo 1', richChapter),
      chapter(
        1,
        'Capítulo 2',
        delta([
          {'insert': 'Segundo capítulo.\n'},
        ]),
      ),
    ]);

    test('lo abre el lector de Littera con índice, estilos y carátula', () {
      final cover = pngBytes(width: 60, height: 90);
      final bytes = writeEpub(book, coverJpeg: cover, modified: now);

      final meta = parseEpubMetadata(bytes);
      expect(meta.title, 'El faro');
      expect(meta.author, 'Ana Ruiz');
      expect(meta.coverBytes, cover);

      final doc = parseEpub(bytes);
      expect(doc.toc.map((e) => e.title), ['Capítulo 1', 'Capítulo 2']);
      final ch1 = doc.blocks[doc.toc.first.blockIndex] as HeadingBlock;
      expect(ch1.text, 'Capítulo 1');

      final texts = doc.blocks.whereType<ParagraphBlock>().map((p) => p.text);
      expect(texts, contains('Una cita <con> símbolos & "comillas"'));
      expect(texts, contains('Segundo capítulo.'));
      final first = doc.blocks.whereType<ParagraphBlock>().firstWhere(
        (p) => p.text.startsWith('Primer párrafo'),
      );
      expect(first.runs.singleWhere((r) => r.bold).text, 'negrita');
      expect(
        doc.blocks
            .whereType<ParagraphBlock>()
            .where((p) => p.kind == ParagraphKind.listItem)
            .map((p) => p.text),
        ['Uno', 'Dos'],
      );
    });

    test(
      'estructura válida: mimetype primero y sin comprimir; XHTML bien formado',
      () {
        final bytes = writeEpub(book, modified: now);
        final archive = ZipDecoder().decodeBytes(bytes);
        final first = archive.files.first;
        expect(first.name, 'mimetype');
        expect(utf8.decode(first.readBytes()!), 'application/epub+zip');
        // En un ZIP, el método "stored" es 0.
        expect(bytes.sublist(8, 10), [0, 0]);

        final opf = utf8.decode(
          archive.findFile('OEBPS/content.opf')!.readBytes()!,
        );
        expect(opf, contains('urn:uuid:3f2a9c1e-0000-4000-8000-000000000001'));
        expect(opf, contains('<meta property="dcterms:modified">2026-11-'));
        expect(opf, contains('Una farera &amp; su secreto'));
        expect(opf, isNot(contains('cover-image'))); // sin carátula

        final ch = utf8.decode(
          archive.findFile('OEBPS/chapter-1.xhtml')!.readBytes()!,
        );
        expect(ch, contains('&lt;con&gt; símbolos &amp; &quot;comillas&quot;'));
        expect(ch, contains('<ul>\n<li>Uno</li>\n<li>Dos</li>\n</ul>'));
        expect(ch, contains('<strong>negrita</strong>'));
      },
    );
  });

  test(
    'PDF con tildes, carátula y un capítulo largo que ocupa varias páginas',
    () async {
      ByteData font(String name) =>
          ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
      final long = delta([
        for (var i = 0; i < 120; i++)
          {
            'insert':
                'Párrafo $i: canción, ñandú, ¿qué?, ¡sí! Texto de relleno.\n',
          },
      ]);
      final book = compileManuscript(manuscript(), [
        chapter(0, 'Capítulo único', long),
      ]);
      final bytes = await buildPdf(
        PdfJob(
          book,
          PdfFontData(
            regular: font('Inter-Regular.ttf'),
            bold: font('Inter-Bold.ttf'),
            italic: font('Inter-Italic.ttf'),
            boldItalic: font('Inter-Bold.ttf'),
          ),
          pngBytes(width: 60, height: 90),
        ),
      );
      expect(looksLikePdf(bytes), isTrue);
      final raw = latin1.decode(bytes);
      // Carátula + portada + al menos 3 páginas de capítulo.
      expect(
        RegExp(r'/Type\s*/Page[^s]').allMatches(raw).length,
        greaterThanOrEqualTo(5),
      );
      expect(raw, contains('/Outlines')); // marcador del capítulo
    },
  );
}
