import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:image/image.dart' as img;
import 'package:littera/data/models/book.dart';
import 'package:littera/features/library/import/book_importer.dart';
import 'package:littera/features/library/import/book_metadata.dart';
import 'package:littera/features/library/import/cover_processor.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('metadatos', () {
    test('EPUB 3: título, autor y carátula (con espacios en la ruta)', () {
      final meta = parseEpubMetadata(buildEpub());
      expect(meta.title, 'El nombre del viento');
      expect(meta.author, 'Patrick Rothfuss');
      expect(meta.coverBytes, isNotNull);
    });

    test('EPUB 2: carátula por <meta name="cover">', () {
      final meta = parseEpubMetadata(buildEpub(epub3: false));
      expect(meta.coverBytes, isNotNull);
    });

    test('EPUB sin carátula ni metadatos', () {
      final meta = parseEpubMetadata(
        buildEpub(title: null, author: null, withCover: false),
      );
      expect(meta.title, isNull);
      expect(meta.author, isNull);
      expect(meta.coverBytes, isNull);
    });

    test('EPUB corrupto no lanza', () {
      final meta = parseEpubMetadata(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(meta.title, isNull);
    });

    test('DOCX: título y autor de docProps/core.xml', () {
      final meta = parseDocxMetadata(buildDocx());
      expect(meta.title, 'Mi novela');
      expect(meta.author, 'Ana');
    });

    test('título desde el nombre de archivo', () {
      expect(
        titleFromFileName('el_nombre-del_viento.epub'),
        'El nombre del viento',
      );
      expect(titleFromFileName('.pdf'), 'Sin título');
    });
  });

  test('la carátula se recorta a 2:3 y se guarda como JPEG 600×900', () async {
    final out = await processCover(pngBytes(width: 1000, height: 500));
    final decoded = img.decodeJpg(out!)!;
    expect(decoded.width, coverWidth);
    expect(decoded.height, coverHeight);
    expect(await processCover(Uint8List.fromList([0, 1, 2])), isNull);
  });

  group('importador', () {
    late TestEnv env;
    late FakePdfCoverRenderer pdf;
    late BookImporter importer;

    setUp(() async {
      env = await TestEnv.create();
      pdf = FakePdfCoverRenderer(result: pngBytes());
      importer = BookImporter(
        repository: env.repository,
        files: env.files,
        pdfCovers: pdf,
      );
    });

    test('importa un EPUB con metadatos y carátula', () async {
      final book = await importer.importBytes('x.epub', buildEpub());
      expect(book.title, 'El nombre del viento');
      expect(book.author, 'Patrick Rothfuss');
      expect(book.format, BookFormat.epub);
      expect(book.status, ReadingStatus.toRead);
      expect(book.coverRef, isNotNull);
      expect(book.hasCustomCover, isFalse);
      expect(env.files.files.keys, containsAll([book.fileRef, book.coverRef]));
      expect(env.books.length, 1);
    });

    test('DOCX sin título usa el nombre del archivo', () async {
      final book = await importer.importBytes(
        'mi_cuento.docx',
        buildDocx(title: null, author: null),
      );
      expect(book.title, 'Mi cuento');
      expect(book.author, '');
      expect(book.coverRef, isNull);
    });

    test('PDF: la carátula sale de la primera página', () async {
      final book = await importer.importBytes('manual.pdf', pdfBytes);
      expect(pdf.calls, 1);
      expect(book.coverRef, isNotNull);
    });

    test('PDF: si falla el render, se importa sin carátula', () async {
      importer = BookImporter(
        repository: env.repository,
        files: env.files,
        pdfCovers: FakePdfCoverRenderer(fail: true),
      );
      final book = await importer.importBytes('manual.pdf', pdfBytes);
      expect(book.coverRef, isNull);
    });

    test('rechaza duplicados', () async {
      final bytes = buildEpub();
      await importer.importBytes('a.epub', bytes);
      expect(
        () => importer.importBytes('copia.epub', bytes),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            contains('Ya está en tu biblioteca'),
          ),
        ),
      );
    });

    test('rechaza .doc con un mensaje claro', () {
      expect(
        () => importer.importBytes('viejo.doc', Uint8List.fromList([1, 2])),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            contains('.docx'),
          ),
        ),
      );
    });

    test('rechaza archivos dañados o de otro formato', () {
      expect(
        () => importer.importBytes('falso.pdf', buildEpub()),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => importer.importBytes('foto.png', pngBytes()),
        throwsA(isA<ImportException>()),
      );
    });
  });
}
