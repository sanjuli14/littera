import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/data/models/highlight.dart';
import 'package:littera/features/backup/backup_service.dart';
import 'package:littera/features/quotes/quotes_export.dart';
import 'package:littera/features/reader/document/reader_document.dart';
import 'package:littera/features/reader/widgets/block_view.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  const blockText =
      'En un lugar de la Mancha, de cuyo nombre no quiero acordarme';

  group('repositorio', () {
    late TestEnv env;
    setUp(() async => env = await TestEnv.create());

    test('guarda el texto citado y su posición', () async {
      final h = await env.highlightsRepository.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 3,
        start: 6,
        end: 11,
        blockText: blockText,
      );
      expect(h.text, 'lugar');
      expect(h.blockIndex, 3);
      expect(h.color, HighlightColor.oro);
      expect(env.highlights.length, 1);
    });

    test('subrayados solapados se fusionan conservando la nota', () async {
      final repo = env.highlightsRepository;
      final first = await repo.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 0,
        start: 0,
        end: 11,
        blockText: blockText,
      );
      await repo.update(first.copyWith(note: 'Inicio famoso'));
      final merged = await repo.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 0,
        start: 6,
        end: 24,
        blockText: blockText,
      );
      expect(env.highlights.length, 1);
      expect(merged.text, 'En un lugar de la Mancha');
      expect(merged.note, 'Inicio famoso');

      // En otro bloque no se fusiona.
      await repo.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 1,
        start: 0,
        end: 5,
        blockText: blockText,
      );
      expect(env.highlights.length, 2);
    });

    test('citas y notas de página (PDF), en orden de lectura', () async {
      final repo = env.highlightsRepository;
      await repo.addPageHighlight(bookId: 'b1', page: 9, note: 'Revisar');
      await repo.addPageHighlight(bookId: 'b1', page: 2, text: ' Una cita ');
      final list = repo.forBook('b1');
      expect(list.map((h) => h.page), [2, 9]);
      expect(list.first.text, 'Una cita');
      expect(list.last.isPageNote, isTrue);
    });

    test('al eliminar el libro se borran sus subrayados', () async {
      await env.books.put('b1', testBook());
      await env.highlightsRepository.addPageHighlight(
        bookId: 'b1',
        page: 1,
        note: 'x',
      );
      await env.highlightsRepository.addPageHighlight(
        bookId: 'otro',
        page: 1,
        note: 'y',
      );
      await env.repository.deleteBook(env.books.get('b1')!);
      expect(env.highlights.values.map((h) => h.bookId), ['otro']);
    });
  });

  test('el texto se divide por subrayados conservando negritas', () {
    final runs = [
      const TextRun('Hola '),
      const TextRun('mundo', bold: true),
      const TextRun(' cruel'),
    ];
    final h = Highlight(
      id: 'h',
      bookId: 'b',
      text: 'a mun',
      blockIndex: 0,
      start: 3,
      end: 8,
      note: 'ojo',
      color: HighlightColor.azul,
      createdAt: DateTime(2026),
    );
    final spans = highlightedSpans(runs, [h]).cast<TextSpan>();
    expect(spans.map((s) => s.text).join(), 'Hola mundo cruel');
    expect(spans.map((s) => s.text), ['Hol', 'a ', 'mun', 'do', ' cruel']);

    final highlighted = spans.where((s) => s.style?.backgroundColor != null);
    expect(highlighted.map((s) => s.text), ['a ', 'mun']);
    expect(
      spans.firstWhere((s) => s.text == 'mun').style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      spans.firstWhere((s) => s.text == 'mun').style?.decoration,
      TextDecoration.underline, // tiene nota
    );
    expect(
      spans.firstWhere((s) => s.text == 'do').style?.backgroundColor,
      isNull,
    );
  });

  test('exportar citas a Markdown agrupadas por libro', () {
    final md = buildQuotesMarkdown(
      [
        Highlight(
          id: '1',
          bookId: 'b',
          text: 'Línea uno\nlínea dos',
          blockIndex: 1,
          note: 'Me gusta',
          createdAt: DateTime(2026, 3, 1),
        ),
        Highlight(
          id: '2',
          bookId: 'a',
          text: '',
          page: 4,
          note: 'Nota suelta',
          createdAt: DateTime(2026, 3, 2),
        ),
      ],
      {
        'a': testBook(id: 'a', title: 'Antes', author: ''),
        'b': testBook(id: 'b', title: 'Brillo', author: 'Ana'),
      },
      now: DateTime(2026, 11, 12),
    );
    expect(md, startsWith('# Mis citas'));
    expect(md.indexOf('## Antes'), lessThan(md.indexOf('## Brillo — Ana')));
    expect(md, contains('> Línea uno\n> línea dos'));
    expect(md, contains('**Nota:** Me gusta'));
    expect(md, contains('Página 4 · 2 mar 2026'));
    expect(md, isNot(contains('> \n')));
  });

  test(
    'la copia de seguridad incluye subrayados y los reasigna al fusionar',
    () async {
      final phone = await TestEnv.create();
      await phone.books.put('a', testBook(id: 'a'));
      phone.files.files['books/a.epub'] = pdfBytes;
      await phone.highlightsRepository.addBlockHighlight(
        bookId: 'a',
        blockIndex: 2,
        start: 0,
        end: 5,
        blockText: blockText,
      );
      BackupService service(TestEnv e) => BackupService(
        books: e.books,
        shelves: e.shelves,
        settings: e.settings,
        meta: e.meta,
        files: e.files,
        highlights: e.highlights,
        writing: e.writingRepository,
        readingLog: e.readingLog,
      );
      final bytes = await service(phone).create(includeBookFiles: false);

      // Otro dispositivo que tiene un libro distinto (otro id y otro hash).
      final tablet = await TestEnv.create();
      await tablet.books.put('x', testBook(id: 'x', title: 'Otro'));

      // El libro del subrayado no está y la copia no trae su archivo:
      // el subrayado no tiene a dónde ir.
      final r1 = await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      expect(r1.highlightsAdded, 0);

      // Con el libro presente, se restaura apuntando a él.
      await tablet.books.put('a', testBook(id: 'a'));
      final r2 = await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      expect(r2.highlightsAdded, 1);
      expect(tablet.highlights.values.single.bookId, 'a');
      expect(tablet.highlights.values.single.text, 'En un');

      // Mismo libro (mismo contenido) con otro id: va al libro local.
      final laptop = await TestEnv.create();
      await laptop.books.put(
        'local',
        testBook(id: 'local', contentHash: 'hash-a'),
      );
      final r3 = await service(laptop)
          .restore(service(laptop).read(bytes), RestoreMode.merge);
      expect(r3.highlightsAdded, 1);
      expect(laptop.highlights.values.single.bookId, 'local');
    },
  );
}
