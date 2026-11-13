import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littera/app/app.dart';
import 'package:littera/features/reminders/reminder_messages.dart';
import 'package:littera/features/reminders/reminder_scheduler.dart';
import 'package:littera/features/updates/app_release.dart';
import 'package:littera/features/updates/update_service.dart';
import 'package:littera/features/updates/updates_provider.dart';

import 'helpers.dart';
import 'reminders_test.dart' show FakeScheduler;

Map<String, Object?> release(
  String tag, {
  bool draft = false,
  bool pre = false,
  bool apk = true,
  String body = '- Mejoras',
  String date = '2026-11-12T10:00:00Z',
}) => {
  'tag_name': tag,
  'name': 'Littera ${tag.substring(1)}',
  'body': body,
  'draft': draft,
  'prerelease': pre,
  'published_at': date,
  'assets': [
    if (apk)
      {
        'name': 'littera-${tag.substring(1)}.apk',
        'browser_download_url': 'https://example.com/$tag.apk',
        'size': 2048,
      },
  ],
};

final releasesJson = jsonEncode([
  release('v1.0.0', body: '- Primera versión', date: '2026-10-01T10:00:00Z'),
  release(
    'v1.2.0',
    body: '# Novedades\n- **Recordatorios** de lectura\n- Modo oscuro nuevo',
  ),
  release('v1.3.0-beta', pre: true),
  release('v9.0.0', draft: true),
  release('v1.1.0', apk: false, date: '2026-11-01T10:00:00Z'),
]);

MockClient githubReturning(String body, {int status = 200}) =>
    MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      expect(request.url.path, '/repos/sanjuli14/littera/releases');
      return http.Response(
        body,
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('versiones', () {
    test('compara versiones con o sin "v" y sufijos', () {
      expect(parseVersion('v1.2'), [1, 2, 0]);
      expect(parseVersion('1.2.3+7'), [1, 2, 3]);
      expect(compareVersions('v1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0', 'v1.0'), 0);
      expect(compareVersions('1.0.1', '1.1.0'), lessThan(0));
    });

    test('lee la respuesta de GitHub: sin borradores ni betas, ordenada', () {
      final list = parseReleases(jsonDecode(releasesJson));
      expect(list.map((r) => r.version), ['1.2.0', '1.1.0', '1.0.0']);
      expect(list.first.apkUrl, 'https://example.com/v1.2.0.apk');
      expect(list.first.apkSize, 2048);
      expect(list[1].hasApk, isFalse);
      expect(parseReleases('basura'), isEmpty);
    });

    test('elige el APK de la arquitectura del móvil', () {
      Map<String, Object?> asset(String name) => {
        'name': name,
        'browser_download_url': 'https://example.com/$name',
        'size': 1,
      };
      final json = [
        {
          'tag_name': 'v2.0.0',
          'published_at': '2026-11-12T10:00:00Z',
          'assets': [
            asset('littera-2.0.0-arm64-v8a.apk'),
            asset('littera-2.0.0-armeabi-v7a.apk'),
            asset('littera-2.0.0-x86_64.apk'),
            asset('notas.txt'),
          ],
        },
      ];
      String? urlFor(String? abi) =>
          parseReleases(json, abi: abi).single.apkUrl;
      expect(urlFor('armeabi-v7a'), endsWith('-armeabi-v7a.apk'));
      expect(urlFor('x86_64'), endsWith('-x86_64.apk'));
      expect(urlFor('arm64-v8a'), endsWith('-arm64-v8a.apk'));
      expect(urlFor(null), endsWith('-arm64-v8a.apk'));

      // Versiones antiguas con un solo APK universal.
      expect(
        pickApk([
          {'name': 'littera-1.0.0.apk'},
        ], 'armeabi-v7a')?['name'],
        'littera-1.0.0.apk',
      );
    });
  });

  group('servicio', () {
    late Box<dynamic> meta;
    setUp(() async => meta = await memoryBox<dynamic>());

    UpdateService service(http.Client client, {String current = '1.0.0'}) =>
        UpdateService(client: client, meta: meta, currentVersion: current);

    test(
      'consulta, guarda una copia y detecta la versión nueva con APK',
      () async {
        final s = service(githubReturning(releasesJson));
        final now = DateTime(2026, 11, 12, 9);
        expect(s.shouldCheck(now), isTrue);
        final releases = await s.fetchReleases(now: now);
        expect(s.newestUpdate(releases)!.version, '1.2.0');
        expect(s.shouldCheck(now.add(const Duration(hours: 3))), isFalse);
        expect(s.shouldCheck(now.add(const Duration(hours: 25))), isTrue);
        // Sin conexión, el historial sigue disponible.
        expect(s.cachedReleases().map((r) => r.version), [
          '1.2.0',
          '1.1.0',
          '1.0.0',
        ]);
      },
    );

    test('si ya tienes la última, no hay actualización', () async {
      final s = service(githubReturning(releasesJson), current: '1.2.0');
      expect(s.newestUpdate(await s.fetchReleases()), isNull);
    });

    test('sin conexión o con error, mensajes claros', () async {
      final offline = service(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(
        () => offline.fetchReleases(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.message,
            'm',
            'Sin conexión a internet.',
          ),
        ),
      );
      final failing = service(githubReturning('{}', status: 403));
      expect(
        () => failing.fetchReleases(),
        throwsA(
          isA<UpdateException>().having((e) => e.message, 'm', contains('403')),
        ),
      );
    });

    test('descarga con progreso, comprueba el tamaño e instala', () async {
      final tmp = await Directory.systemTemp.createTemp('apk');
      addTearDown(() => tmp.delete(recursive: true));
      final opened = <String>[];
      final bytes = List<int>.generate(2048, (i) => i % 256);
      final s = UpdateService(
        client: MockClient.streaming((request, _) async {
          expect(request.url.toString(), 'https://example.com/v1.2.0.apk');
          return http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 1024), bytes.sublist(1024)]),
            200,
            contentLength: 2048,
          );
        }),
        meta: meta,
        currentVersion: '1.0.0',
        downloadsDir: () async => tmp,
        openInstaller: (path) async {
          opened.add(path);
          return true;
        },
      );
      final r = parseReleases(jsonDecode(releasesJson)).first;
      final progress = <double>[];
      final apk = await s.download(r, onProgress: progress.add);
      expect(await apk.readAsBytes(), bytes);
      expect(progress, [0.5, 1.0, 1.0]);
      await s.install(apk);
      expect(opened.single, endsWith('littera-1.2.0.apk'));
    });

    test('una descarga incompleta se descarta', () async {
      final tmp = await Directory.systemTemp.createTemp('apk');
      addTearDown(() => tmp.delete(recursive: true));
      final s = UpdateService(
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.value(List.filled(100, 1)),
            200,
            contentLength: 2048,
          ),
        ),
        meta: meta,
        currentVersion: '1.0.0',
        downloadsDir: () async => tmp,
      );
      final r = parseReleases(jsonDecode(releasesJson)).first;
      expect(() => s.download(r), throwsA(isA<UpdateException>()));
    });

    test('se notifica una sola vez por versión', () async {
      final s = service(githubReturning(releasesJson));
      expect(await s.markNotified('1.2.0'), isTrue);
      expect(await s.markNotified('1.2.0'), isFalse);
      expect(await s.markNotified('1.3.0'), isTrue);
    });
  });

  test(
    'al abrir la app: consulta, avisa una vez y respeta el límite diario',
    () async {
      final meta = await memoryBox<dynamic>();
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response.bytes(utf8.encode(releasesJson), 200);
      });
      final fake = FakeScheduler();
      final container = ProviderContainer(
        overrides: [
          updateServiceProvider.overrideWithValue(
            UpdateService(client: client, meta: meta, currentVersion: '1.0.0'),
          ),
          reminderSchedulerProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(updatesProvider.notifier);
      final now = DateTime(2026, 11, 12, 9);

      await notifier.checkOnLaunch(now: now);
      expect(container.read(updatesProvider).available!.version, '1.2.0');
      expect(fake.shown.single.title, 'Littera 1.2.0 ya está aquí');
      expect(fake.shown.single.body, 'Novedades');
      expect(fake.shown.single.payload, ReminderMessage.updatePayload);

      await notifier.checkOnLaunch(now: now.add(const Duration(hours: 1)));
      expect(requests, 1); // límite de una consulta al día
      await notifier.checkOnLaunch(now: now.add(const Duration(days: 2)));
      expect(requests, 2);
      expect(fake.shown, hasLength(1)); // la misma versión no se repite

      await notifier.dismissBanner();
      expect(container.read(updatesProvider).showBanner, isFalse);
    },
  );

  group('interfaz', () {
    Future<void> pumpWithUpdate(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1080 / 412;
      addTearDown(tester.view.reset);
      final env = (await tester.runAsync(TestEnv.create))!;
      final service = UpdateService(
        client: githubReturning(releasesJson),
        meta: env.meta,
        currentVersion: '1.0.0',
      );
      await tester.runAsync(() async {
        await service.fetchReleases(now: DateTime.now());
        await env.books.put('b1', testBook());
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...env.overrides,
            updateServiceProvider.overrideWithValue(service),
            currentVersionProvider.overrideWithValue('1.0.0'),
          ],
          child: const LitteraApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tarjeta en Inicio y hoja con las novedades', (tester) async {
      await pumpWithUpdate(tester);
      expect(find.text('Littera 1.2.0 ya está aquí'), findsOneWidget);
      await tester.tap(find.text('Littera 1.2.0 ya está aquí'));
      await tester.pumpAndSettle();
      expect(find.text('NUEVA VERSIÓN'), findsOneWidget);
      expect(find.text('Novedades'), findsWidgets); // título de las notas
      expect(find.text('Modo oscuro nuevo'), findsOneWidget);
      expect(find.text('Descargar e instalar'), findsOneWidget);
    });

    testWidgets('"Ahora no" oculta la tarjeta', (tester) async {
      await pumpWithUpdate(tester);
      await tester.tap(find.byTooltip('Ahora no').first);
      await tester.pumpAndSettle();
      expect(find.text('Littera 1.2.0 ya está aquí'), findsNothing);
    });

    testWidgets('Ajustes → Novedades muestra el historial', (tester) async {
      await pumpWithUpdate(tester);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Hay una versión nueva: 1.2.0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Novedades'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Novedades'));
      await tester.pumpAndSettle();

      expect(find.text('Tienes la versión 1.0.0'), findsOneWidget);
      expect(find.text('Actualizar a 1.2.0'), findsOneWidget);
      expect(find.text('Littera 1.2.0'), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Instalada'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Primera versión'), findsOneWidget);
    });
  });
}
