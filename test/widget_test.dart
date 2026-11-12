import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/app_settings.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/models/shelf.dart';
import 'package:littera/data/repositories/settings_repository.dart';
import 'package:littera/features/library/widgets/shelf_filter_bar.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<TestEnv> pumpApp(
    WidgetTester tester, {
    List<Book> books = const [],
    List<Shelf> shelves = const [],
  }) async {
    // Pantalla de móvil: 412×915 lógicos.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);

    final env = (await tester.runAsync(TestEnv.create))!;
    await tester.runAsync(() async {
      for (final b in books) {
        await env.books.put(b.id, b);
      }
      for (final s in shelves) {
        await env.shelves.put(s.id, s);
      }
    });
    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, child: const LitteraApp()),
    );
    await tester.pumpAndSettle();
    return env;
  }

  /// Títulos dentro de la cuadrícula. Cada tarjeta muestra el título dos
  /// veces (debajo y en la carátula generada), por eso se usa findsWidgets.
  Finder bookTitle(String title) =>
      find.descendant(of: find.byType(GridView), matching: find.text(title));

  testWidgets('biblioteca vacía muestra la invitación a importar', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(find.text('Importar libro'), findsOneWidget);
  });

  testWidgets('muestra libros y filtra por estado y estante', (tester) async {
    final shelf = Shelf(
      id: 's1',
      name: 'Favoritos',
      order: 0,
      createdAt: DateTime(2026),
    );
    await pumpApp(
      tester,
      shelves: [shelf],
      books: [
        testBook(id: 'a', title: 'Rayuela', status: ReadingStatus.reading),
        testBook(id: 'b', title: 'Ficciones', shelfIds: ['s1']),
        testBook(
          id: 'c',
          title: 'Pedro Páramo',
          status: ReadingStatus.finished,
        ),
      ],
    );

    expect(find.text('Todos  3'), findsWidgets);
    expect(bookTitle('Rayuela'), findsWidgets);
    expect(bookTitle('Ficciones'), findsWidgets);

    await tester.tap(find.text('Leyendo  1'));
    await tester.pumpAndSettle();
    expect(bookTitle('Rayuela'), findsWidgets);
    expect(bookTitle('Ficciones'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Favoritos  1'),
      150,
      scrollable: find.descendant(
        of: find.byType(ShelfFilterBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Favoritos  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos  1'));
    await tester.pumpAndSettle();
    expect(bookTitle('Ficciones'), findsWidgets);
    expect(bookTitle('Rayuela'), findsNothing);
  });

  testWidgets('la búsqueda ignora tildes y mayúsculas', (tester) async {
    await pumpApp(
      tester,
      books: [
        testBook(id: 'a', title: 'Pedro Páramo', author: 'Juan Rulfo'),
        testBook(id: 'b', title: 'Rayuela', author: 'Julio Cortázar'),
      ],
    );
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'PARAMO');
    await tester.pumpAndSettle();
    expect(bookTitle('Pedro Páramo'), findsWidgets);
    expect(bookTitle('Rayuela'), findsNothing);

    await tester.enterText(find.byType(TextField), 'cortazar');
    await tester.pumpAndSettle();
    expect(bookTitle('Rayuela'), findsWidgets);
  });

  testWidgets('cambiar a vista de lista se guarda en ajustes', (tester) async {
    final env = await pumpApp(tester, books: [testBook()]);
    await tester.tap(find.byTooltip('Ver como lista'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsWidgets);
    expect(env.settings.get(HiveKeys.appSettings)?.libraryGridView, isFalse);
  });

  testWidgets('ficha del libro: cambia estado y añade a estante', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      books: [testBook(title: 'Rayuela')],
      shelves: [
        Shelf(id: 's1', name: 'Favoritos', order: 0, createdAt: DateTime(2026)),
      ],
    );

    await tester.tap(bookTitle('Rayuela').first);
    await tester.pumpAndSettle();
    expect(find.text('Autora'), findsWidgets);

    await tester.tap(find.text('Leyendo'));
    await tester.pumpAndSettle();
    expect(env.books.get('b1')!.status, ReadingStatus.reading);

    final chip = find.widgetWithText(FilterChip, 'Favoritos');
    await tester.scrollUntilVisible(
      chip,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(env.books.get('b1')!.shelfIds, ['s1']);
  });

  testWidgets('elegir Sepia cambia el tema', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sepia'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.surface, const Color(0xFFF2E8D2));
    expect(app.themeMode, ThemeMode.light);
  });

  test('el tema elegido se guarda en disco y se recupera', () async {
    final container = ProviderContainer();
    await container
        .read(settingsProvider.notifier)
        .setThemePreference(AppThemePreference.dark);
    container.dispose();

    await Hive.box<AppSettings>(HiveBoxes.settings).close();
    await Hive.openBox<AppSettings>(HiveBoxes.settings);

    final reopened = ProviderContainer();
    expect(
      reopened.read(settingsProvider).themePreference,
      AppThemePreference.dark,
    );
    reopened.dispose();
  });

  test('registra la versión de esquema', () {
    expect(
      Hive.box<dynamic>(HiveBoxes.meta).get(HiveKeys.schemaVersion),
      currentSchemaVersion,
    );
  });

  testWidgets('cada libro se anuncia como un botón con sus datos', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      books: [
        testBook(
          id: 'a',
          title: 'Rayuela',
          author: 'Julio Cortázar',
          status: ReadingStatus.reading,
          progress: 0.42,
        ),
      ],
    );
    expect(
      find.bySemanticsLabel('Rayuela, de Julio Cortázar, Leyendo, 42 % leído'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
