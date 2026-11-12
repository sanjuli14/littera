import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/app_settings.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/features/reminders/reminder_messages.dart';
import 'package:littera/features/reminders/reminder_scheduler.dart';

import 'helpers.dart';

/// Programador de prueba: guarda lo programado.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.grant = true});
  final bool grant;
  (int, int, ReminderMessage)? daily;
  (DateTime, ReminderMessage)? nudge;
  int permissionRequests = 0;

  @override
  bool get isSupported => true;
  @override
  Stream<String> get taps => const Stream.empty();
  final shown = <ReminderMessage>[];
  @override
  Future<void> showNow(ReminderMessage m) async => shown.add(m);
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> scheduleDaily(int h, int m, ReminderMessage msg) async =>
      daily = (h, m, msg);
  @override
  Future<void> cancelDaily() async => daily = null;
  @override
  Future<void> scheduleNudge(DateTime when, ReminderMessage msg) async =>
      nudge = (when, msg);
  @override
  Future<void> cancelNudge() async => nudge = null;
}

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final now = DateTime(2026, 11, 12, 18, 30);

  group('mensajes', () {
    test('el aviso diario habla del libro en curso', () {
      final msg = dailyReminderMessage([
        testBook(
          id: 'a',
          title: 'Viejo',
          status: ReadingStatus.reading,
        ).copyWith(lastOpenedAt: DateTime(2026, 1, 1), progress: 0.2),
        testBook(
          id: 'b',
          title: 'El mar',
          status: ReadingStatus.reading,
        ).copyWith(lastOpenedAt: DateTime(2026, 11, 10), progress: 0.62),
      ]);
      expect(msg.body, '«El mar» te espera: vas por el 62 %.');
      expect(msg.payload, 'book:b');
      expect(ReminderMessage.bookIdFromPayload(msg.payload), 'b');
    });

    test(
      'sin libro en curso propone empezar uno; sin libros, un texto suave',
      () {
        expect(
          dailyReminderMessage([testBook(title: 'Ceniza')]).body,
          '¿Y si hoy empiezas «Ceniza»?',
        );
        expect(dailyReminderMessage([]).bookId, isNull);
      },
    );

    test('"¡Ey, ya casi!" para el libro más avanzado, 3 días después', () {
      final plan = finishNudge(
        [
          testBook(
            id: 'a',
            title: 'Poco',
            status: ReadingStatus.reading,
          ).copyWith(lastOpenedAt: DateTime(2026, 11, 11), progress: 0.3),
          testBook(
            id: 'b',
            title: 'Casi',
            status: ReadingStatus.reading,
          ).copyWith(lastOpenedAt: DateTime(2026, 11, 11, 22), progress: 0.85),
        ],
        now: now,
        hour: 21,
        minute: 0,
      )!;
      expect(plan.message.title, '¡Ey, ya casi!');
      expect(plan.message.body, contains('«Casi» (85 %)'));
      expect(plan.when, DateTime(2026, 11, 15, 21)); // 14 a las 22 → día 15
    });

    test('si ya pasó el plazo, se avisa en la próxima hora elegida', () {
      final plan = finishNudge(
        [
          testBook(
            id: 'a',
            title: 'Olvidado',
            status: ReadingStatus.reading,
          ).copyWith(lastOpenedAt: DateTime(2026, 10, 1), progress: 0.4),
        ],
        now: now,
        hour: 21,
        minute: 0,
      )!;
      expect(plan.message.title, '¿Seguimos con «Olvidado»?');
      expect(plan.when, DateTime(2026, 11, 12, 21));
    });

    test('sin libros a medias no hay aviso', () {
      expect(
        finishNudge(
          [
            testBook(status: ReadingStatus.finished),
            testBook(
              id: 'x',
              status: ReadingStatus.reading,
            ).copyWith(lastOpenedAt: now, progress: 0.02),
          ],
          now: now,
          hour: 21,
          minute: 0,
        ),
        isNull,
      );
    });
  });

  Future<(TestEnv, FakeScheduler)> pumpSettings(
    WidgetTester tester, {
    bool grant = true,
    AppSettings settings = const AppSettings(onboardingDone: true),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(TestEnv.create))!;
    final fake = FakeScheduler(grant: grant);
    await tester.runAsync(() async {
      await env.settings.put(HiveKeys.appSettings, settings);
      await env.books.put(
        'b1',
        testBook(
          title: 'El mar',
          status: ReadingStatus.reading,
        ).copyWith(lastOpenedAt: DateTime.now(), progress: 0.5),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          reminderSchedulerProvider.overrideWithValue(fake),
        ],
        child: const LitteraApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    return (env, fake);
  }

  testWidgets('activar el recordatorio pide permiso y lo programa', (
    tester,
  ) async {
    final (env, fake) = await pumpSettings(tester);
    expect(find.text('Recordatorios'), findsOneWidget);
    expect(fake.daily, isNull);

    await tester.tap(find.text('Recordarme leer cada día'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); // espera de reprogramación
    await tester.pumpAndSettle();

    expect(fake.permissionRequests, 1);
    expect(env.settings.get(HiveKeys.appSettings)!.reminderEnabled, isTrue);
    expect(fake.daily!.$1, 21);
    expect(fake.daily!.$3.body, contains('«El mar»'));
  });

  testWidgets('si se niega el permiso, no se activa y se explica', (
    tester,
  ) async {
    final (env, fake) = await pumpSettings(tester, grant: false);
    await tester.tap(find.text('Recordarme leer cada día'));
    await tester.pumpAndSettle();
    expect(env.settings.get(HiveKeys.appSettings)!.reminderEnabled, isFalse);
    expect(
      find.text(
        'Activa las notificaciones de Littera en los ajustes del móvil',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(fake.daily, isNull);
  });

  testWidgets('desactivar cancela el aviso diario', (tester) async {
    final (env, fake) = await pumpSettings(
      tester,
      settings: const AppSettings(
        onboardingDone: true,
        reminderEnabled: true,
        nudgesEnabled: true,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(fake.daily, isNotNull);
    expect(fake.nudge, isNotNull);

    await tester.tap(find.text('Recordarme leer cada día'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(fake.daily, isNull);
    expect(env.settings.get(HiveKeys.appSettings)!.reminderEnabled, isFalse);
  });

  testWidgets('en Web (sin soporte) se indica que es para Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(TestEnv.create))!;
    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, child: const LitteraApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibles en la app para Android'), findsOneWidget);
  });
}
