import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/models/manuscript.dart';
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
      ProviderScope(overrides: env.overrides, child: const LitteraApp()),
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
    expect(find.text('Hoy: 0 / 500 palabras'), findsOneWidget);
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
    expect(find.text('Hoy 5 / 500'), findsOneWidget);
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
}
