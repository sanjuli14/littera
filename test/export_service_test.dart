import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/features/export/export_service.dart';
import 'package:littera/features/export/pdf_writer.dart';
import 'package:littera/features/library/import/book_importer.dart';
import 'package:littera/features/library/import/book_metadata.dart';
import 'package:littera/features/reader/document/epub_parser.dart';
import 'package:littera/features/reader/document/reader_document.dart';

import 'helpers.dart';

String delta(String text) => jsonEncode([
  {'insert': '$text\n'},
]);

Future<PdfFontData> fontsFromDisk() async {
  ByteData font(String name) =>
      ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
  return PdfFontData(
    regular: font('Inter-Regular.ttf'),
    bold: font('Inter-Bold.ttf'),
    italic: font('Inter-Italic.ttf'),
    boldItalic: font('Inter-Bold.ttf'),
  );
}

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  late TestEnv env;
  late ExportService service;
  late String manuscriptId;
  late String chapterId;
  var coverRenders = 0;

  setUp(() async {
    env = await TestEnv.create();
    coverRenders = 0;
    service = ExportService(
      writing: env.writingRepository,
      files: env.files,
      importer: BookImporter(
        repository: env.repository,
        files: env.files,
        pdfCovers: FakePdfCoverRenderer(result: pngBytes()),
      ),
      loadFonts: fontsFromDisk,
      renderCover: (title, author) async {
        coverRenders++;
        return pngBytes(width: 600, height: 900);
      },
    );
    final m = await env.writingRepository.createManuscript('El faro');
    await env.writingRepository.updateManuscript(
      env.manuscripts.get(m.id)!.copyWith(author: 'Ana Ruiz'),
    );
    manuscriptId = m.id;
    chapterId = env.writingRepository.chaptersOf(m.id).single.id;
    await env.writingRepository.saveChapterContent(
      chapterId,
      delta('Había una vez un faro.'),
    );
  });

  test('exporta EPUB con carátula generada si la obra no tiene', () async {
    final file = await service.export(manuscriptId, ExportFormat.epub);
    expect(file.fileName, 'el-faro.epub');
    expect(file.mimeType, 'application/epub+zip');
    expect(coverRenders, 1);
    final meta = parseEpubMetadata(file.bytes);
    expect(meta.title, 'El faro');
    expect(meta.author, 'Ana Ruiz');
    expect(meta.coverBytes, isNotNull);
    expect(
      parseEpub(file.bytes).blocks.whereType<Object>().length,
      greaterThan(1),
    );
  });

  test('usa la carátula de la obra si la tiene', () async {
    await env.writingRepository.setCover(
      env.manuscripts.get(manuscriptId)!,
      pngBytes(width: 300, height: 450),
    );
    await service.export(manuscriptId, ExportFormat.epub);
    expect(coverRenders, 0);
  });

  test('exporta PDF', () async {
    final file = await service.export(manuscriptId, ExportFormat.pdf);
    expect(file.fileName, 'el-faro.pdf');
    expect(looksLikePdf(file.bytes), isTrue);
  });

  test('una obra sin texto no se exporta', () async {
    final empty = await env.writingRepository.createManuscript('Vacía');
    expect(
      () => service.export(empty.id, ExportFormat.epub),
      throwsA(isA<ExportException>()),
    );
  });

  test(
    'añadir a la biblioteca y reexportar actualiza el mismo libro',
    () async {
      final first = await service.addToLibrary(
        manuscriptId,
        await service.export(manuscriptId, ExportFormat.epub),
      );
      expect(first.isOwnWork, isTrue);
      expect(first.sourceManuscriptId, manuscriptId);
      expect(first.title, 'El faro');
      expect(first.coverRef, isNotNull);

      // Se lee un poco y se pone en un estante.
      await env.repository.saveProgress(first.id, 'b:3', 0.4);
      await env.repository.setStatus(first, ReadingStatus.reading);

      // Exportar sin cambios: mismo libro, nada cambia.
      final same = await service.addToLibrary(
        manuscriptId,
        await service.export(manuscriptId, ExportFormat.epub),
      );
      expect(same.id, first.id);
      expect(same.position, 'b:3');

      // Se edita y se vuelve a exportar: se actualiza el mismo libro.
      await env.writingRepository.saveChapterContent(
        chapterId,
        delta('Había una vez un faro. Y una farera.'),
      );
      final updated = await service.addToLibrary(
        manuscriptId,
        await service.export(manuscriptId, ExportFormat.epub),
      );
      expect(updated.id, first.id);
      expect(env.books.length, 1);
      expect(updated.contentHash, isNot(first.contentHash));
      expect(updated.status, ReadingStatus.reading); // se conserva
      expect(updated.position, isNull); // el texto cambió
      expect(updated.progress, 0);
      final paragraphs = parseEpub(env.files.files[updated.fileRef]!).blocks
          .whereType<ParagraphBlock>()
          .map((p) => p.text);
      expect(paragraphs, contains('Había una vez un faro. Y una farera.'));
    },
  );

  test('el mismo EPUB sale idéntico aunque pase el tiempo', () async {
    final a = await service.export(manuscriptId, ExportFormat.epub);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final b = await service.export(manuscriptId, ExportFormat.epub);
    expect(b.bytes, a.bytes);
  });

  test('reexportar un PDF sin cambios no toca el libro', () async {
    final first = await service.addToLibrary(
      manuscriptId,
      await service.export(manuscriptId, ExportFormat.pdf),
    );
    await env.repository.saveProgress(first.id, 'p:7', 0.5);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final again = await service.addToLibrary(
      manuscriptId,
      await service.export(manuscriptId, ExportFormat.pdf),
    );
    expect(again.id, first.id);
    expect(again.position, 'p:7');
    expect(again.contentHash, first.contentHash);
  });

  test('EPUB y PDF de la misma obra son libros distintos', () async {
    await service.addToLibrary(
      manuscriptId,
      await service.export(manuscriptId, ExportFormat.epub),
    );
    await service.addToLibrary(
      manuscriptId,
      await service.export(manuscriptId, ExportFormat.pdf),
    );
    expect(env.books.values.map((b) => b.format).toSet(), {
      BookFormat.epub,
      BookFormat.pdf,
    });
  });

  test('si el mismo archivo ya se importó a mano, avisa', () async {
    final file = await service.export(manuscriptId, ExportFormat.epub);
    await BookImporter(
      repository: env.repository,
      files: env.files,
      pdfCovers: FakePdfCoverRenderer(),
    ).importBytes(file.fileName, file.bytes);
    expect(
      () => service.addToLibrary(manuscriptId, file),
      throwsA(isA<ImportException>()),
    );
  });
}
