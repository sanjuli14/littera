import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littera/app/app.dart';
import 'package:littera/features/explore/gutenberg_book.dart';
import 'package:littera/features/explore/gutendex_client.dart';

import 'helpers.dart';

Map<String, dynamic> _bookJson({
  int id = 2000,
  String title = 'Don Quijote',
  bool epub = true,
}) => {
  'id': id,
  'title': title,
  'authors': [
    {
      'name': 'Cervantes Saavedra, Miguel de',
      'birth_year': 1547,
      'death_year': 1616,
    },
  ],
  'translators': [],
  'subjects': ['Spain -- Social life and customs -- 16th century -- Fiction'],
  'bookshelves': ['Category: Novels'],
  'summaries': ['"Don Quijote" is a novel by Miguel de Cervantes...'],
  'languages': ['es'],
  'copyright': false,
  'media_type': 'Text',
  'formats': {
    'image/jpeg':
        'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg',
    if (epub)
      'application/epub+zip':
          'https://www.gutenberg.org/ebooks/$id.epub3.images',
    'text/html': 'https://www.gutenberg.org/ebooks/$id.html.images',
  },
  'download_count': 45210,
};

String _pageJson(List<Map<String, dynamic>> books, {String? next}) =>
    jsonEncode({
      'count': books.length,
      'next': next,
      'previous': null,
      'results': books,
    });

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('modelo', () {
    test('lee un libro de Gutendex', () {
      final book = GutenbergBook.fromJson(_bookJson());
      expect(book.id, 2000);
      expect(book.authorLine, 'Miguel de Cervantes Saavedra');
      expect(book.authors.single.lifespan, '1547–1616');
      expect(book.epubUrl, contains('2000.epub'));
      expect(book.canDownload, isTrue);
      // Carátula y descargas desde la réplica, con gutenberg.org al final.
      expect(
        book.coverUrl,
        'https://gutenberg.pglaf.org/cache/epub/2000/pg2000.cover.medium.jpg',
      );
      expect(book.epubUrls, [
        'https://gutenberg.pglaf.org/cache/epub/2000/pg2000-images-3.epub',
        'https://gutenberg.pglaf.org/cache/epub/2000/pg2000-images.epub',
        'https://www.gutenberg.org/ebooks/2000.epub3.images',
      ]);
      expect(book.fileName, 'Don Quijote.epub');
    });

    test('limpia títulos y nombres raros', () {
      expect(cleanTitle('Niebla\r\n(Nivola)'), 'Niebla');
      expect(cleanTitle('  '), 'Sin título');
      expect(
        const GutenbergPerson(name: 'Alighieri, Dante, 1265-1321').displayName,
        'Dante Alighieri',
      );
      expect(const GutenbergPerson(name: 'Homer').displayName, 'Homer');
      expect(
        const GutenbergPerson(name: 'x', birthYear: -800).lifespan,
        'n. 800 a. C.',
      );
      final book = GutenbergBook.fromJson(
        _bookJson(title: 'Rimas: poesía / prosa?'),
      );
      expect(book.fileName, 'Rimas poesía prosa.epub');
    });
  });

  group('cliente', () {
    late Box<dynamic> meta;
    setUp(() async => meta = await memoryBox<dynamic>());

    test('filtra por idioma y dominio público, y guarda en caché', () async {
      final requests = <Uri>[];
      final client = GutendexClient(
        client: MockClient((req) async {
          requests.add(req.url);
          expect(req.headers['User-Agent'], startsWith('Littera/1.2.3'));
          return http.Response(_pageJson([_bookJson()]), 200);
        }),
        meta: meta,
        appVersion: '1.2.3',
      );

      final page = await client.books(language: 'es', search: ' quijote ');
      expect(page.results.single.title, 'Don Quijote');
      final params = requests.single.queryParameters;
      expect(params['languages'], 'es');
      expect(params['search'], 'quijote');
      expect(params['copyright'], 'false');
      expect(params.containsKey('topic'), isFalse);

      // La segunda vez sale de la caché.
      await client.books(language: 'es', search: 'quijote');
      expect(requests, hasLength(1));
    });

    test('caché: fresca 24 h; luego se muestra y se refresca detrás', () async {
      var now = DateTime(2026, 11, 1);
      var calls = 0;
      var title = 'Primera';
      final client = GutendexClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(_pageJson([_bookJson(title: title)]), 200);
        }),
        meta: meta,
        appVersion: '1',
        clock: () => now,
      );
      Future<String> first() async =>
          (await client.books(topic: 'poetry')).results.single.title;

      expect(await first(), 'Primera');
      now = now.add(const Duration(hours: 23));
      expect(await first(), 'Primera');
      expect(calls, 1);

      // Pasado un día: devuelve lo guardado al instante y actualiza.
      title = 'Segunda';
      now = now.add(const Duration(hours: 2));
      expect(await first(), 'Primera');
      await pumpEventQueue();
      expect(calls, 2);
      expect(await first(), 'Segunda');

      // Con más de una semana ya no sirve: se espera a la red.
      title = 'Tercera';
      now = now.add(const Duration(days: 8));
      expect(await first(), 'Tercera');
      expect(calls, 3);
    });

    test(
      'cola: como mucho 2 a la vez y sin pedir dos veces lo mismo',
      () async {
        var running = 0;
        var peak = 0;
        final urls = <String>[];
        final client = GutendexClient(
          client: MockClient((req) async {
            urls.add(req.url.toString());
            running++;
            peak = running > peak ? running : peak;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            running--;
            return http.Response(_pageJson([]), 200);
          }),
          meta: meta,
          appVersion: '1',
        );
        await Future.wait([
          for (final t in ['a', 'b', 'c', 'd', 'a', 'a'])
            client.books(topic: t),
        ]);
        expect(peak, 2);
        expect(urls, hasLength(4));
      },
    );

    test('reintenta una vez si el catálogo da error 5xx', () async {
      var calls = 0;
      final client = GutendexClient(
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('', 502)
              : http.Response(_pageJson([_bookJson()]), 200);
        }),
        meta: meta,
        appVersion: '1',
        retryDelay: Duration.zero,
      );
      expect((await client.books()).results, hasLength(1));
      expect(calls, 2);
    });

    test('si la réplica falla, descarga de gutenberg.org', () async {
      final epub = buildEpub();
      final hosts = <String>[];
      final client = GutendexClient(
        client: MockClient((req) async {
          hosts.add(req.url.host);
          return req.url.host == 'www.gutenberg.org'
              ? http.Response.bytes(epub, 200)
              : http.Response('mantenimiento', 503);
        }),
        meta: meta,
        appVersion: '1',
      );
      final bytes = await client.downloadEpub(
        GutenbergBook.fromJson(_bookJson()),
      );
      expect(bytes, epub);
      expect(hosts, [
        'gutenberg.pglaf.org',
        'gutenberg.pglaf.org',
        'www.gutenberg.org',
      ]);
    });

    test('si todo Gutenberg está caído, lo dice', () async {
      final client = GutendexClient(
        client: MockClient((_) async => http.Response('', 503)),
        meta: meta,
        appVersion: '1',
      );
      await expectLater(
        client.downloadEpub(GutenbergBook.fromJson(_bookJson())),
        throwsA(
          isA<ExploreException>().having(
            (e) => e.message,
            'message',
            contains('no está disponible'),
          ),
        ),
      );
    });

    test('errores de red y de servidor dan mensajes claros', () async {
      GutendexClient failing(Future<http.Response> Function() f) =>
          GutendexClient(
            client: MockClient((_) => f()),
            meta: meta,
            appVersion: '1',
            retryDelay: Duration.zero,
          );

      await expectLater(
        failing(() async => http.Response('', 503)).book(1),
        throwsA(
          isA<ExploreException>().having(
            (e) => e.message,
            'message',
            contains('503'),
          ),
        ),
      );
      await expectLater(
        failing(() async => throw const SocketException('x')).book(1),
        throwsA(
          isA<ExploreException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('rechaza una descarga que no es un EPUB', () async {
      final client = GutendexClient(
        client: MockClient((_) async => http.Response('<html>', 200)),
        meta: meta,
        appVersion: '1',
      );
      await expectLater(
        client.downloadEpub(GutenbergBook.fromJson(_bookJson())),
        throwsA(isA<ExploreException>()),
      );
      await expectLater(
        client.downloadEpub(GutenbergBook.fromJson(_bookJson(epub: false))),
        throwsA(isA<ExploreException>()),
      );
    });
  });

  testWidgets('Explorar → ficha → descargar añade el libro a la biblioteca', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 412;
    addTearDown(tester.view.reset);

    final env = (await tester.runAsync(TestEnv.create))!;
    final epub = buildEpub(title: 'Don Quijote', author: 'Cervantes');
    final mock = MockClient((req) async {
      if (req.url.host == 'gutenberg.pglaf.org') {
        return http.Response.bytes(epub, 200);
      }
      return http.Response(_pageJson([_bookJson()]), 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          gutendexClientProvider.overrideWithValue(
            GutendexClient(client: mock, meta: env.meta, appVersion: '1'),
          ),
        ],
        child: const LitteraApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    expect(find.text('Los más leídos'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Don Quijote, de')).first);
    await tester.pumpAndSettle();
    expect(find.text('Miguel de Cervantes Saavedra (1547–1616)'), findsOne);

    await tester.tap(find.text('Descargar a mi biblioteca'));
    // La importación lee el EPUB en otro isolate: hace falta tiempo real.
    for (var i = 0; i < 50 && find.text('Leer ahora').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Durations.short2));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(env.books.values.single.title, 'Don Quijote');
    expect(find.text('Leer ahora'), findsOneWidget);
  });
}
