import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/features/backup/backup_screen.dart';
import 'package:littera/features/backup/backup_service.dart';

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
    int bookCount = 0,
    DateTime? lastBackup,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);

    final env = (await tester.runAsync(TestEnv.create))!;
    await tester.runAsync(() async {
      for (var i = 0; i < bookCount; i++) {
        final Book b = testBook(id: 'b$i', title: 'Libro $i');
        await env.books.put(b.id, b);
      }
      if (lastBackup != null) {
        await env.meta.put('lastBackupAt', lastBackup.toIso8601String());
      }
    });
    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, child: const LitteraApp()),
    );
    await tester.pumpAndSettle();
    return env;
  }

  testWidgets('recuerda hacer copia con 3+ libros y sin copia reciente', (
    tester,
  ) async {
    await pumpApp(tester, bookCount: 3);
    expect(
      find.text('Haz una copia para no perder tu biblioteca'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(
      find.text('Haz una copia para no perder tu biblioteca'),
      findsNothing,
    );
  });

  testWidgets('no molesta con pocos libros ni con una copia reciente', (
    tester,
  ) async {
    await pumpApp(tester, bookCount: 2);
    expect(find.text('Hacer copia'), findsNothing);
  });

  testWidgets('copia reciente: sin aviso', (tester) async {
    await pumpApp(
      tester,
      bookCount: 5,
      lastBackup: DateTime.now().subtract(const Duration(days: 2)),
    );
    expect(find.text('Hacer copia'), findsNothing);
  });

  testWidgets('copia antigua: avisa con los días', (tester) async {
    await pumpApp(
      tester,
      bookCount: 5,
      lastBackup: DateTime.now().subtract(const Duration(days: 20)),
    );
    expect(find.text('Hace 20 días de tu última copia'), findsOneWidget);
  });

  testWidgets('desde el aviso se llega a la pantalla de copia', (tester) async {
    await pumpApp(tester, bookCount: 3);
    await tester.tap(find.text('Hacer copia'));
    await tester.pumpAndSettle();

    expect(find.text('Copia de seguridad'), findsOneWidget);
    expect(find.text('Aún no has hecho ninguna copia'), findsOneWidget);
    expect(find.textContaining('3 libros · 0 estantes'), findsOneWidget);
    final exportButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Exportar copia completa'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(exportButton.onPressed, isNotNull);
  });

  testWidgets('Ajustes muestra la última copia; sin libros no se exporta', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no has hecho ninguna copia'), findsOneWidget);

    await tester.tap(find.text('Copia de seguridad'));
    await tester.pumpAndSettle();
    final exportButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Exportar copia completa'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(exportButton.onPressed, isNull);
    expect(find.text('Restaurar desde un archivo .littera'), findsOneWidget);
  });

  test('texto de última copia', () {
    final now = DateTime(2026, 11, 12, 18);
    expect(lastBackupLabel(null), 'Aún no has hecho ninguna copia');
    expect(
      lastBackupLabel(DateTime(2026, 11, 12, 9), now: now),
      'Última copia: 12 nov 2026 (hoy)',
    );
    expect(
      lastBackupLabel(DateTime(2026, 11, 11, 9), now: now),
      'Última copia: 11 nov 2026 (ayer)',
    );
    expect(
      lastBackupLabel(DateTime(2026, 11, 2, 9), now: now),
      'Última copia: 2 nov 2026 (hace 10 días)',
    );
  });

  test('resumen de restauración', () {
    expect(
      restoreSummary(const RestoreResult()),
      'Tu biblioteca ya estaba al día.',
    );
    expect(
      restoreSummary(
        const RestoreResult(added: 2, updated: 1, shelvesAdded: 1),
      ),
      '2 libros añadidos, 1 libro actualizado, 1 estante nuevo.',
    );
    expect(
      restoreSummary(const RestoreResult(skipped: 3)),
      contains('3 libros no se restauraron'),
    );
  });

  test('plurales', () {
    expect(plural(1, 'obra', 'obras'), '1 obra');
    expect(plural(0, 'obra', 'obras'), '0 obras');
    expect(plural(5, 'libro', 'libros'), '5 libros');
  });

  testWidgets('restaurar una copia actualiza la fecha de última copia', (
    tester,
  ) async {
    final env = await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await tester.runAsync(
      () => container
          .read(lastBackupProvider.notifier)
          .markAtLeast(DateTime(2026, 11, 1)),
    );
    expect(container.read(lastBackupProvider), DateTime(2026, 11, 1));
    // Una copia más antigua no hace retroceder la fecha.
    await tester.runAsync(
      () => container
          .read(lastBackupProvider.notifier)
          .markAtLeast(DateTime(2026, 10, 1)),
    );
    expect(container.read(lastBackupProvider), DateTime(2026, 11, 1));
    expect(
      env.meta.get('lastBackupAt'),
      DateTime(2026, 11, 1).toIso8601String(),
    );
  });
}
