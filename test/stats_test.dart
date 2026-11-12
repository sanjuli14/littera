import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/repositories/stats_repository.dart';
import 'package:littera/features/backup/backup_service.dart';
import 'package:littera/features/stats/reading_tracker.dart';
import 'package:littera/features/stats/stats_screen.dart';
import 'package:littera/features/writing/word_count.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('contador de lectura', () {
    late DateTime now;
    late List<int> flushed;
    late ReadingTracker tracker;

    setUp(() {
      now = DateTime(2026, 11, 12, 20);
      flushed = [];
      tracker = ReadingTracker(
        clock: () => now,
        onFlush: (seconds, _) => flushed.add(seconds),
      );
    });

    void advance(Duration d) => now = now.add(d);

    test('cuenta el tiempo con actividad regular', () {
      for (var i = 0; i < 10; i++) {
        advance(const Duration(minutes: 1));
        tracker.activity();
      }
      tracker.flush();
      expect(flushed.fold(0, (a, b) => a + b), 600);
    });

    test('deja de contar tras 5 minutos sin actividad', () {
      advance(const Duration(minutes: 2));
      tracker.activity();
      advance(const Duration(hours: 1)); // se quedó abierto
      tracker.flush();
      expect(flushed.fold(0, (a, b) => a + b), (2 + 5) * 60);

      // Al volver, el hueco no cuenta.
      tracker.activity();
      advance(const Duration(minutes: 3));
      tracker.flush();
      expect(flushed.fold(0, (a, b) => a + b), (2 + 5 + 3) * 60);
    });

    test('anotar varias veces no duplica', () {
      advance(const Duration(minutes: 1));
      tracker.flush();
      tracker.flush();
      expect(flushed, [60]);
    });

    test('en segundo plano no cuenta', () {
      advance(const Duration(minutes: 4));
      tracker.pause();
      advance(const Duration(hours: 2));
      tracker.flush(); // en pausa: nada
      tracker.resume();
      advance(const Duration(minutes: 1));
      tracker.flush();
      expect(flushed, [240, 60]);
    });
  });

  group('estadísticas', () {
    late TestEnv env;
    late StatsRepository stats;
    setUp(() async {
      env = await TestEnv.create();
      stats = env.statsRepository;
    });

    test('suma la lectura por día y por libro', () async {
      final d = DateTime(2026, 11, 12, 9);
      await stats.addReadingTime('a', d, 300);
      await stats.addReadingTime('a', d, 120);
      await stats.addReadingTime('b', d, 60);
      await stats.addReadingTime('a', DateTime(2026, 11, 11), 600);
      expect(stats.readingSecondsOn(d), 480);
      expect(stats.readingSecondsForBook('a'), 1020);
      expect(stats.readingSecondsInYear(2026), 1080);
    });

    test('palabras por día de todas las obras', () async {
      await env.writingLog.put('m1|2026-11-12', [100, 350]);
      await env.writingLog.put('m2|2026-11-12', [0, 50]);
      await env.writingLog.put('m1|2026-11-11', [80, 100]);
      await env.writingLog.put('m1|2026-11-10', [100, 80]); // borró texto
      expect(stats.wordsByDay(), {'2026-11-12': 300, '2026-11-11': 20});
      expect(stats.wordsInYear(2026), 320);
    });

    test(
      'terminar un libro guarda la fecha; volver a leerlo la borra',
      () async {
        await env.books.put('a', testBook(id: 'a'));
        await env.repository.setStatus(
          env.books.get('a')!,
          ReadingStatus.finished,
        );
        expect(env.books.get('a')!.finishedAt?.year, DateTime.now().year);
        expect(stats.finishedInYear(DateTime.now().year).single.id, 'a');

        await env.repository.setStatus(
          env.books.get('a')!,
          ReadingStatus.reading,
        );
        expect(env.books.get('a')!.finishedAt, isNull);

        await env.repository.markFinished('a');
        expect(env.books.get('a')!.finishedAt, isNotNull);
        expect(env.books.get('a')!.progress, 1);
      },
    );
  });

  test(
    'el registro de lectura va en la copia y no se duplica al fusionar',
    () async {
      final phone = await TestEnv.create();
      await phone.books.put('a', testBook(id: 'a'));
      phone.files.files['books/a.epub'] = pdfBytes;
      await phone.statsRepository.addReadingTime(
        'a',
        DateTime(2026, 11, 12),
        900,
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
      final bytes = await service(phone).create(includeBookFiles: true);

      final tablet = await TestEnv.create();
      await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      expect(tablet.statsRepository.readingSecondsForBook('a'), 900);

      // Mismo libro con otro id: los minutos se asignan al libro local.
      final laptop = await TestEnv.create();
      await laptop.books.put('x', testBook(id: 'x', contentHash: 'hash-a'));
      await service(laptop)
          .restore(service(laptop).read(bytes), RestoreMode.merge);
      expect(laptop.statsRepository.readingSecondsForBook('x'), 900);
      expect(laptop.readingLog.keys.single, startsWith('x|'));
    },
  );

  test('formato de minutos', () {
    expect(formatMinutes(0), '0 min');
    expect(formatMinutes(45), '45 min');
    expect(formatMinutes(60), '1 h');
    expect(formatMinutes(135), '2 h 15 min');
  });

  testWidgets(
    'la pantalla muestra lectura, escritura y libros del año, sin metas',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1080 / 412;
      addTearDown(tester.view.reset);
      final env = (await tester.runAsync(TestEnv.create))!;
      final now = DateTime.now();
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          await env.statsRepository.addReadingTime(
            'a',
            now.subtract(Duration(days: i)),
            25 * 60,
          );
        }
        await env.writingLog.put('m|${dayKey(now)}', [0, 420]);
        await env.books.put(
          'a',
          testBook(
            id: 'a',
            title: 'Rayuela',
            status: ReadingStatus.finished,
          ).copyWith(finishedAt: now),
        );
      });
      await tester.pumpWidget(
        ProviderScope(overrides: env.overrides, child: const LitteraApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Estadísticas'));
      await tester.pumpAndSettle();

      expect(find.text('1 h 15 min'), findsOneWidget); // esta semana
      expect(find.text('25 min'), findsOneWidget); // hoy
      expect(find.text('1 libro terminado'), findsOneWidget);
      expect(find.text('420 palabras'), findsNWidgets(2)); // hoy y esta semana

      expect(find.text('Tu ${now.year}'), findsOneWidget);
      expect(find.textContaining('Meta'), findsNothing);
    },
  );
}
