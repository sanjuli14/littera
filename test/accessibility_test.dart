import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/models/highlight.dart';
import 'package:littera/data/models/shelf.dart';
import 'package:littera/features/reader/document/docx_parser.dart';
import 'package:littera/features/reader/document/epub_parser.dart';
import 'package:littera/features/reader/reader_providers.dart';

import 'helpers.dart';

/// Recorre las pantallas principales en un móvil pequeño con texto grande.
/// Cualquier desbordamiento (RenderFlex overflow) hace fallar el test.
void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets(
      'todas las pantallas a 360 px con texto al ${(scale * 100).round()} %',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 740 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final env = (await tester.runAsync(TestEnv.create))!;
        await tester.runAsync(() async {
          await env.shelves.put(
            's1',
            Shelf(
              id: 's1',
              name: 'Clásicos españoles',
              order: 0,
              createdAt: DateTime(2026),
            ),
          );
          for (var i = 0; i < 4; i++) {
            final b = testBook(
              id: 'b$i',
              title: 'Un título bastante largo para probar el número $i',
              author: 'Autora con nombre compuesto',
              status: i.isEven ? ReadingStatus.reading : ReadingStatus.finished,
              shelfIds: ['s1'],
              progress: 0.4,
            ).copyWith(finishedAt: i.isOdd ? DateTime.now() : null);
            await env.books.put(b.id, b);
          }
          env.files.files['books/b0.epub'] = buildEpub();
          await env.highlights.put(
            'h1',
            Highlight(
              id: 'h1',
              bookId: 'b0',
              text:
                  'Una cita bastante larga que ocupa varias líneas en pantalla',
              blockIndex: 1,
              start: 0,
              end: 10,
              note: 'Una nota también larga para ver cómo se ajusta',
              createdAt: DateTime(2026),
            ),
          );
          final m = await env.writingRepository.createManuscript(
            'Una novela con un título muy largo',
          );
          final c = env.writingRepository.chaptersOf(m.id).single;
          await env.writingRepository.saveChapterContent(
            c.id,
            jsonEncode([
              {'insert': 'Había una vez un faro en la costa.\n'},
            ]),
          );
          await env.statsRepository.addReadingTime('b0', DateTime.now(), 3000);
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...env.overrides,
              documentParserProvider.overrideWithValue(
                (f, b) async =>
                    f == BookFormat.epub ? parseEpub(b) : parseDocx(b),
              ),
            ],
            child: const LitteraApp(),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> tap(Finder f) async {
          await tester.ensureVisible(f.first);
          await tester.pumpAndSettle();
          await tester.tap(f.first);
          await tester.pumpAndSettle();
        }

        Future<void> back() => tap(find.byType(BackButton));

        // Biblioteca → ficha → lector.
        expect(find.text('Biblioteca'), findsWidgets);
        await tap(find.byTooltip('Ver como lista'));
        await tap(find.byTooltip('Ver como cuadrícula'));
        final book0 = find.descendant(
          of: find.byType(GridView),
          matching: find.textContaining('probar el número 0'),
        );
        await tester.scrollUntilVisible(
          book0.last,
          200,
          scrollable: find
              .descendant(
                of: find.byType(GridView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(book0.last);
        expect(find.text('Autora con nombre compuesto'), findsWidgets);
        await tester.scrollUntilVisible(
          find.textContaining('Continuar'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.scrollUntilVisible(
          find.text('Estantes'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.scrollUntilVisible(
          find.textContaining('Continuar'),
          -200,
          scrollable: find.byType(Scrollable).last,
        );
        await tap(find.textContaining('Continuar'));
        await tap(find.byTooltip('Ajustes de lectura'));
        await tester.tapAt(const Offset(180, 40)); // cerrar la hoja
        await tester.pumpAndSettle();
        await tap(find.byTooltip('Notas'));
        await tester.tapAt(const Offset(180, 40));
        await tester.pumpAndSettle();
        await tap(find.byTooltip('Volver'));
        await back();

        // Estadísticas.
        await tap(find.byTooltip('Estadísticas'));
        expect(find.text('Racha de lectura'), findsOneWidget);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        await back();

        // Citas.
        await tap(find.text('Citas'));
        expect(find.text('Mis citas'), findsOneWidget);

        // Escribir → obra → editor.
        await tap(find.text('Escribir'));
        await tap(find.text('Una novela con un título muy largo'));
        await tap(find.text('Fichas'));
        await tap(find.text('Capítulos'));
        await tap(find.text('Capítulo 1'));
        await tap(find.byType(BackButton));
        await back();

        // Ajustes → copia de seguridad.
        await tap(find.text('Ajustes'));
        await tap(find.text('Copia de seguridad'));
        await tester.scrollUntilVisible(
          find.text('Exportar copia completa'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.scrollUntilVisible(
          find.textContaining('Restaurar desde'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await back();
      },
    );
  }
}
