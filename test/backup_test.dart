import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/app_settings.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/models/shelf.dart';
import 'package:littera/features/backup/backup_service.dart';

import 'helpers.dart';

/// Un "dispositivo": boxes + archivos en memoria + servicio.
class Device {
  Device._(this.env, this.meta);
  final TestEnv env;
  final Box<dynamic> meta;

  static Future<Device> create() async =>
      Device._(await TestEnv.create(), await memoryBox<dynamic>());

  BackupService get service => BackupService(
    books: env.books,
    shelves: env.shelves,
    settings: env.settings,
    meta: meta,
    files: env.files,
    highlights: env.highlights,
  );

  Future<void> addBook(Book book, {bool withCover = false}) async {
    var b = book;
    env.files.files[b.fileRef] = Uint8List.fromList(
      utf8.encode('libro ${b.id}'),
    );
    if (withCover) {
      final ref = 'covers/${b.id}_1.jpg';
      env.files.files[ref] = Uint8List.fromList([1, 2, 3, b.id.length]);
      b = b.copyWith(coverRef: ref, hasCustomCover: true);
    }
    await env.books.put(b.id, b);
  }
}

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  late Device phone;
  setUp(() async {
    phone = await Device.create();
    final shelf = Shelf(
      id: 's1',
      name: 'Favoritos',
      order: 0,
      createdAt: DateTime(2026),
    );
    await phone.env.shelves.put(shelf.id, shelf);
    await phone.addBook(
      testBook(
        id: 'a',
        title: 'Rayuela',
        status: ReadingStatus.reading,
        shelfIds: ['s1'],
      ).copyWith(
        position: 'b:42',
        progress: 0.3,
        lastOpenedAt: DateTime(2026, 5),
      ),
      withCover: true,
    );
    await phone.addBook(testBook(id: 'b', title: 'Ficciones'));
    await phone.env.settings.put(
      HiveKeys.appSettings,
      const AppSettings(
        readerFontSize: 22,
        themePreference: AppThemePreference.sepia,
      ),
    );
  });

  test(
    'ida y vuelta: copia completa → app reinstalada → todo idéntico',
    () async {
      final bytes = await phone.service.create(includeBookFiles: true);

      final newPhone = await Device.create(); // app recién instalada
      final contents = newPhone.service.read(bytes);
      expect(contents.manifest.bookCount, 2);
      expect(contents.manifest.includesBookFiles, isTrue);
      expect(contents.booksWithFiles, 2);

      final result = await newPhone.service.restore(
        contents,
        RestoreMode.replace,
      );
      expect(result.added, 2);
      expect(result.skipped, 0);

      final a = newPhone.env.books.get('a')!;
      expect(a.title, 'Rayuela');
      expect(a.status, ReadingStatus.reading);
      expect(a.position, 'b:42');
      expect(a.progress, 0.3);
      expect(a.shelfIds, ['s1']);
      expect(a.hasCustomCover, isTrue);
      expect(newPhone.env.shelves.get('s1')!.name, 'Favoritos');
      expect(
        newPhone.env.files.files.keys.toSet(),
        phone.env.files.files.keys.toSet(),
      );
      expect(
        newPhone.env.files.files[a.fileRef],
        phone.env.files.files[a.fileRef],
      );

      final settings = newPhone.env.settings.get(HiveKeys.appSettings)!;
      expect(settings.readerFontSize, 22);
      expect(settings.themePreference, AppThemePreference.sepia);
    },
  );

  test('"solo datos" no incluye libros pero sí carátulas', () async {
    final bytes = await phone.service.create(includeBookFiles: false);
    final contents = (await Device.create()).service.read(bytes);
    expect(contents.manifest.includesBookFiles, isFalse);
    expect(contents.files.keys.where((k) => k.startsWith('books/')), isEmpty);
    expect(
      contents.files.keys.where((k) => k.startsWith('covers/')),
      hasLength(1),
    );
  });

  test('"solo datos" no permite reemplazar (perdería los libros)', () async {
    final bytes = await phone.service.create(includeBookFiles: false);
    final contents = phone.service.read(bytes);
    expect(
      () => phone.service.restore(contents, RestoreMode.replace),
      throwsA(isA<BackupException>()),
    );
    expect(phone.env.books.length, 2); // nada cambió
  });

  test(
    'reemplazar borra lo que no está en la copia, incluidos sus archivos',
    () async {
      final bytes = await phone.service.create(includeBookFiles: true);
      await phone.addBook(testBook(id: 'c', title: 'Extra'));
      expect(phone.env.files.files.containsKey('books/c.epub'), isTrue);

      await phone.service.restore(
        phone.service.read(bytes),
        RestoreMode.replace,
      );
      expect(phone.env.books.keys.toSet(), {'a', 'b'});
      expect(phone.env.files.files.containsKey('books/c.epub'), isFalse);
      expect(phone.env.files.files.containsKey('books/a.epub'), isTrue);
    },
  );

  test(
    'fusionar: añade lo nuevo, conserva lo local y une estantes por nombre',
    () async {
      final bytes = await phone.service.create(includeBookFiles: true);

      final tablet = await Device.create();
      // La tablet ya tiene "Ficciones" (mismo contenido, otro id) y un estante
      // "favoritos" con otro id.
      await tablet.env.shelves.put(
        'local-fav',
        Shelf(
          id: 'local-fav',
          name: 'favoritos',
          order: 0,
          createdAt: DateTime(2026),
        ),
      );
      await tablet.addBook(
        testBook(id: 'otro-id', title: 'Ficciones (mía)').copyWith(),
      );
      // Mismo hash que 'b' en el teléfono:
      final mine = tablet.env.books.get('otro-id')!;
      await tablet.env.books.put(
        mine.id,
        Book(
          id: mine.id,
          title: mine.title,
          author: mine.author,
          format: mine.format,
          fileRef: mine.fileRef,
          originalFileName: mine.originalFileName,
          fileSize: mine.fileSize,
          contentHash: 'hash-b',
          addedAt: mine.addedAt,
        ),
      );
      await tablet.addBook(testBook(id: 'z', title: 'Solo en la tablet'));

      final result = await tablet.service.restore(
        tablet.service.read(bytes),
        RestoreMode.merge,
      );
      expect(result.added, 1); // Rayuela
      expect(result.shelvesAdded, 0); // "Favoritos" ya existía como "favoritos"
      expect(tablet.env.books.keys.toSet(), {'a', 'otro-id', 'z'});
      expect(tablet.env.books.get('a')!.shelfIds, ['local-fav']);
      expect(tablet.env.books.get('otro-id')!.title, 'Ficciones (mía)');
      expect(tablet.env.shelves.length, 1);
    },
  );

  test(
    'fusionar actualiza el progreso solo si la copia es más reciente',
    () async {
      final bytes = await phone.service.create(includeBookFiles: false);

      final other = await Device.create();
      await other.addBook(
        testBook(id: 'a', title: 'Rayuela').copyWith(
          position: 'b:5',
          progress: 0.05,
          lastOpenedAt: DateTime(2026, 1),
        ),
      );
      await other.addBook(
        testBook(id: 'b', title: 'Ficciones').copyWith(
          position: 'b:99',
          progress: 0.9,
          lastOpenedAt: DateTime(2026, 12),
        ),
      );

      final result = await other.service.restore(
        other.service.read(bytes),
        RestoreMode.merge,
      );
      expect(result.skipped, 0);
      expect(other.env.books.get('a')!.position, 'b:42'); // copia más nueva
      expect(
        other.env.books.get('a')!.hasCustomCover,
        isTrue,
      ); // trae su carátula
      expect(other.env.books.get('b')!.position, 'b:99'); // local más nuevo
    },
  );

  test(
    'fusionar "solo datos" en una app vacía omite los libros sin archivo',
    () async {
      final bytes = await phone.service.create(includeBookFiles: false);
      final empty = await Device.create();
      final result = await empty.service.restore(
        empty.service.read(bytes),
        RestoreMode.merge,
      );
      expect(result.added, 0);
      expect(result.skipped, 2);
      expect(empty.env.books.isEmpty, isTrue);
    },
  );

  group('validación', () {
    test('rechaza archivos que no son copias de Littera', () {
      expect(
        () => phone.service.read(pngBytes()),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => phone.service.read(buildEpub()),
        throwsA(isA<BackupException>()),
      );
    });

    test('rechaza copias de una versión más nueva', () {
      final zip = buildZip({
        'manifest.json': jsonEncode({
          'format': 'littera-backup',
          'formatVersion': 99,
        }),
      });
      expect(
        () => phone.service.read(zip),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'm',
            contains('más nueva'),
          ),
        ),
      );
    });

    test('ignora rutas peligrosas y registros inválidos', () {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({'format': 'littera-backup', 'formatVersion': 1}),
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'data/books.json',
            jsonEncode([
              {'id': 'ok', 'fileRef': 'books/ok.pdf', 'format': 'pdf'},
              {'title': 'sin id'},
              'basura',
            ]),
          ),
        )
        ..addFile(ArchiveFile.bytes('files/books/ok.pdf', [1]))
        ..addFile(ArchiveFile.bytes('files/../../etc/passwd', [1]))
        ..addFile(ArchiveFile.bytes('files/otros/x.bin', [1]));
      final contents = phone.service.read(ZipEncoder().encodeBytes(archive));
      expect(contents.books.map((b) => b.id), ['ok']);
      expect(contents.files.keys, ['books/ok.pdf']);
    });
  });

  test('registra la fecha de la última copia', () async {
    expect(phone.service.lastBackupAt, isNull);
    await phone.service.markBackedUp(DateTime(2026, 11, 12));
    expect(phone.service.lastBackupAt, DateTime(2026, 11, 12));
  });

  test('nombre de archivo sugerido', () {
    final d = DateTime(2026, 3, 7);
    expect(
      BackupService.suggestedFileName(includeBookFiles: true, now: d),
      'littera-2026-03-07.littera',
    );
    expect(
      BackupService.suggestedFileName(includeBookFiles: false, now: d),
      'littera-2026-03-07-datos.littera',
    );
  });
}
