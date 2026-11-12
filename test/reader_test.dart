import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/models/highlight.dart';
import 'package:littera/features/reader/document/docx_parser.dart';
import 'package:littera/features/reader/document/epub_parser.dart';
import 'package:littera/features/reader/reader_providers.dart';

import 'helpers.dart';

const _container =
    '<?xml version="1.0"?><container version="1.0" '
    'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

/// EPUB de 3 capítulos con 40 párrafos cada uno.
Uint8List _longEpub() {
  final files = <String, String>{
    'META-INF/container.xml': _container,
    'OEBPS/content.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"><metadata/><manifest>'
        '${[for (var c = 1; c <= 3; c++) '<item id="c$c" href="c$c.html" media-type="application/xhtml+xml"/>'].join()}'
        '</manifest><spine>'
        '${[for (var c = 1; c <= 3; c++) '<itemref idref="c$c"/>'].join()}'
        '</spine></package>',
  };
  for (var c = 1; c <= 3; c++) {
    final paragraphs = [
      for (var p = 1; p <= 40; p++)
        '<p>Capítulo $c, párrafo $p. Texto de relleno para que la línea ocupe espacio.</p>',
    ].join();
    files['OEBPS/c$c.html'] =
        '<html><body><h1>Capítulo $c</h1>$paragraphs</body></html>';
  }
  return buildZip(files);
}

const paragraph1Text =
    'Capítulo 1, párrafo 1. Texto de relleno para que la línea ocupe espacio.';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  /// Monta la app con un libro EPUB largo y abre el lector desde la ficha.
  Future<TestEnv> openReader(WidgetTester tester, {String? position}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);

    final env = (await tester.runAsync(TestEnv.create))!;
    final book = Book(
      id: 'b1',
      title: 'Libro largo',
      author: 'Autora',
      format: BookFormat.epub,
      fileRef: 'books/b1.epub',
      originalFileName: 'largo.epub',
      fileSize: 1,
      contentHash: 'h',
      addedAt: DateTime(2026),
      position: position,
    );
    await tester.runAsync(() async {
      await env.books.put(book.id, book);
      env.files.files[book.fileRef] = _longEpub();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          // Sin isolates: el reloj simulado de los tests no los espera.
          documentParserProvider.overrideWithValue(
            (format, bytes) async =>
                format == BookFormat.epub ? parseEpub(bytes) : parseDocx(bytes),
          ),
        ],
        child: const LitteraApp(),
      ),
    );
    await tester.pumpAndSettle();
    await openBookFromLibrary(tester, 'b1');
    await tester.tap(find.text('Leer'));
    await tester.pumpAndSettle();
    return env;
  }

  testWidgets('abrir el libro lo marca como "Leyendo" y muestra el texto', (
    tester,
  ) async {
    final env = await openReader(tester);
    expect(find.text('Capítulo 1'), findsWidgets);
    expect(find.textContaining('Capítulo 1, párrafo 1.'), findsOneWidget);

    final book = env.books.get('b1')!;
    expect(book.status, ReadingStatus.reading);
    expect(book.lastOpenedAt, isNotNull);
  });

  testWidgets('al desplazarse guarda la posición y el progreso', (
    tester,
  ) async {
    final env = await openReader(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1)); // retardo de guardado

    final book = env.books.get('b1')!;
    final pos = ReadingPosition.parse(book.position);
    expect(pos, isA<BlockPosition>());
    expect((pos! as BlockPosition).index, greaterThan(10));
    expect(book.progress, greaterThan(0));
  });

  testWidgets('al reabrir vuelve a la posición guardada', (tester) async {
    await openReader(tester, position: 'b:70');
    await tester.pumpAndSettle();
    expect(find.textContaining('Capítulo 1, párrafo 1.'), findsNothing);
    // Bloque 70 = capítulo 2 (41 bloques por capítulo), párrafo 29.
    expect(find.textContaining('Capítulo 2, párrafo 29.'), findsOneWidget);
  });

  testWidgets('el índice salta al capítulo elegido', (tester) async {
    await openReader(tester);
    await tester.tap(find.byTooltip('Índice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Capítulo 3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Capítulo 3, párrafo 1.'), findsOneWidget);
    expect(find.textContaining('Capítulo 1, párrafo 1.'), findsNothing);
  });

  testWidgets('los ajustes de letra se aplican y se guardan', (tester) async {
    final env = await openReader(tester);
    await tester.tap(find.byTooltip('Ajustes de lectura'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Letra más grande'));
    await tester.pump();
    await tester.tap(find.byTooltip('Letra más grande'));
    await tester.pump();
    await tester.tap(find.text('Sepia'));
    await tester.pumpAndSettle();

    final settings = env.settings.get(HiveKeys.appSettings)!;
    expect(settings.readerFontSize, 20);
    expect(settings.readerTheme.name, 'sepia');

    final paragraph = tester.widget<EditableText>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.textSpan?.toPlainText() ?? '').startsWith(
                'Capítulo 1, párrafo 1.',
              ),
        ),
        matching: find.byType(EditableText),
      ),
    );
    expect(paragraph.style.fontSize, 20);
  });

  testWidgets('al llegar al final ofrece marcarlo como terminado', (
    tester,
  ) async {
    final env = await openReader(tester);
    await tester.tap(find.byTooltip('Índice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Capítulo 3'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -20000),
      5000,
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Terminaste el libro?'), findsOneWidget);
    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();
    final book = env.books.get('b1')!;
    expect(book.status, ReadingStatus.finished);
    expect(book.progress, 1);
  });

  /// Párrafo 1 del capítulo 1 = bloque 1.
  Finder paragraph1() => find.byWidgetPredicate(
    (w) =>
        w is SelectableText &&
        (w.textSpan?.toPlainText() ?? '').startsWith('Capítulo 1, párrafo 1.'),
  );

  testWidgets('un subrayado guardado se pinta sobre el texto', (tester) async {
    final env = await openReader(tester);
    await tester.runAsync(
      () => env.highlightsRepository.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 1,
        start: 0,
        end: 10,
        blockText: paragraph1Text,
        color: HighlightColor.verde,
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<SelectableText>(paragraph1());
    final spans = widget.textSpan!.children!.cast<TextSpan>();
    expect(spans.first.text, 'Capítulo 1');
    expect(spans.first.style?.backgroundColor, isNotNull);
    expect(spans[1].style?.backgroundColor, isNull);
  });

  testWidgets('seleccionar texto y pulsar "Subrayar" lo guarda', (
    tester,
  ) async {
    final env = await openReader(tester);
    await tester.longPress(paragraph1());
    await tester.pumpAndSettle();
    expect(find.text('Subrayar'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);

    await tester.tap(find.text('Subrayar'));
    await tester.pumpAndSettle();
    final saved = env.highlights.values.single;
    expect(saved.bookId, 'b1');
    expect(saved.blockIndex, 1);
    expect(saved.text, isNotEmpty);
    expect(paragraph1Text, contains(saved.text));
  });

  testWidgets('panel de notas: lista y salta al subrayado', (tester) async {
    final env = await openReader(tester);
    await tester.runAsync(() async {
      final h = await env.highlightsRepository.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 100, // capítulo 3
        start: 0,
        end: 10,
        blockText: 'Capítulo 3, párrafo 18. Texto',
      );
      await env.highlightsRepository.update(h.copyWith(note: 'Volver aquí'));
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notas'));
    await tester.pumpAndSettle();
    expect(find.text('Volver aquí'), findsOneWidget);
    expect(find.textContaining('Capítulo 3 ·'), findsOneWidget);

    await tester.tap(find.text('Volver aquí'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Capítulo 1, párrafo 1.'), findsNothing);
    expect(find.textContaining('Capítulo 3, párrafo 18.'), findsOneWidget);
  });

  testWidgets('"Mis citas": agrupa, busca y abre el libro en la cita', (
    tester,
  ) async {
    final env = await openReader(tester);
    await tester.runAsync(() async {
      final repo = env.highlightsRepository;
      await repo.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 60,
        start: 0,
        end: 10,
        blockText: 'Capítulo 2, párrafo 19. Texto',
      );
      final second = await repo.addBlockHighlight(
        bookId: 'b1',
        blockIndex: 5,
        start: 0,
        end: 10,
        blockText: 'Capítulo 1, párrafo 5. Texto',
      );
      await repo.update(second.copyWith(note: 'Idea para mi novela'));
    });
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citas'));
    await tester.pumpAndSettle();

    expect(find.text('Mis citas'), findsOneWidget);
    expect(find.text('2 citas'), findsOneWidget);
    expect(find.text('“Capítulo 2”'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'novela');
    await tester.pumpAndSettle();
    expect(find.text('“Capítulo 2”'), findsNothing);
    expect(find.text('Idea para mi novela'), findsOneWidget);

    await tester.tap(find.text('Idea para mi novela'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Capítulo 1, párrafo 5.'), findsOneWidget);
    expect(find.textContaining('Capítulo 1, párrafo 1.'), findsNothing);
  });

  testWidgets(
    'con lector de pantalla las barras no se ocultan al desplazarse',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openReader(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('Índice'), findsWidgets);
      expect(find.widgetWithText(ListTile, 'Capítulo 3'), findsOneWidget);
    },
  );
}
