import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/models/manuscript.dart';
import 'package:littera/features/export/export_service.dart';
import 'package:littera/features/library/import/book_importer.dart';
import 'package:littera/features/library/widgets/shelf_filter_bar.dart';
import 'package:littera/features/writing/word_count.dart';
import 'package:littera/features/writing/writing_screen.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<TestEnv> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(TestEnv.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          // Sin carátula generada (dibujarla necesita tiempo real).
          exportServiceProvider.overrideWith(
            (ref) => ExportService(
              writing: env.writingRepository,
              files: env.files,
              importer: ref.watch(bookImporterProvider),
              renderCover: (_, _) async => null,
            ),
          ),
        ],
        child: const LitteraApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribir'));
    await tester.pumpAndSettle();
    return env;
  }

  Future<void> createManuscript(WidgetTester tester, String title) async {
    await tester.tap(find.text('Nueva obra'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
  }

  /// Quill necesita que el texto termine en salto de línea.
  void typeInQuill(WidgetTester tester, String text) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$text\n',
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('formato del contador de palabras', () {
    expect(formatWordCount(0), '0 palabras');
    expect(formatWordCount(1), '1 palabra');
    expect(formatWordCount(12345), '12.345 palabras');
    expect(formatWordCount(1234567), '1.234.567 palabras');
  });

  testWidgets('crear una obra la abre con su primer capítulo', (tester) async {
    final env = await pumpApp(tester);
    expect(find.text('Aún no tienes manuscritos'), findsOneWidget);

    await createManuscript(tester, 'El faro');
    expect(find.text('El faro'), findsWidgets);
    expect(find.text('Capítulo 1'), findsOneWidget);
    expect(find.textContaining('/ 500'), findsNothing); // sin metas
    expect(env.manuscripts.length, 1);
  });

  testWidgets('escribir guarda solo y cuenta las palabras del día', (
    tester,
  ) async {
    final env = await pumpApp(tester);
    await createManuscript(tester, 'El faro');
    await tester.tap(find.text('Capítulo 1'));
    await tester.pumpAndSettle();
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.text('Guardado'), findsOneWidget);

    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    typeInQuill(tester, 'Había una vez un faro');
    await tester.pump();
    expect(find.text('Sin guardar'), findsOneWidget);
    expect(find.text('5 palabras'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // guardado automático
    await tester.pumpAndSettle();
    expect(find.text('Guardado'), findsOneWidget);

    final chapter = env.chapters.values.single;
    expect(plainTextFromDelta(chapter.content).trim(), 'Había una vez un faro');
    expect(chapter.wordCount, 5);
  });

  testWidgets('al salir del editor se guarda lo pendiente', (tester) async {
    final env = await pumpApp(tester);
    await createManuscript(tester, 'El faro');
    await tester.tap(find.text('Capítulo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    typeInQuill(tester, 'Sin esperar');
    await tester.pump();

    await tester.tap(find.byType(BackButton)); // antes del guardado automático
    await tester.pumpAndSettle();
    expect(env.chapters.values.single.wordCount, 2);
    expect(find.textContaining('2 palabras'), findsWidgets);
  });

  testWidgets('añadir capítulos y fichas', (tester) async {
    final env = await pumpApp(tester);
    await createManuscript(tester, 'El faro');

    await tester.tap(find.text('Capítulo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Capítulo 2'), findsOneWidget);

    await tester.tap(find.text('Fichas'));
    await tester.pumpAndSettle();
    expect(find.text('Sin fichas todavía'), findsOneWidget);
    await tester.tap(find.text('Ficha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Marina');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción'),
      'Farera, 40 años',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Personajes'), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);
    expect(env.entities.values.single.kind, EntityKind.character);
  });

  testWidgets('exportar la obra la añade a la biblioteca en "Mis obras"', (
    tester,
  ) async {
    final env = await pumpApp(tester);
    final m = (await tester.runAsync(() async {
      final repo = env.writingRepository;
      final m = await repo.createManuscript('El faro');
      final c = repo.chaptersOf(m.id).single;
      await repo.saveChapterContent(c.id, '[{"insert":"Había una vez.\\n"}]');
      return m;
    }))!;
    await tester.pumpAndSettle();
    await tester.tap(find.text('El faro'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exportar'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar obra'), findsOneWidget);
    await tester.tap(
      find.text('Guardar el archivo'),
    ); // sin diálogo del sistema
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar EPUB'));
    // La lectura de metadatos corre en un isolate: dejar pasar tiempo real.
    for (var i = 0; i < 20 && env.books.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final book = env.books.values.single;
    expect(book.isOwnWork, isTrue);
    expect(book.sourceManuscriptId, m.id);
    expect(find.text('Añadida a tu biblioteca'), findsOneWidget);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('Obra propia'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mis obras  1'),
      150,
      scrollable: find.descendant(
        of: find.byType(ShelfFilterBar),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Mis obras  1'), findsOneWidget);
  });
}
