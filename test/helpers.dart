import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:image/image.dart' as img;
import 'package:littera/core/storage/file_store.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/app_settings.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/models/shelf.dart';
import 'package:littera/data/repositories/library_repository.dart';
import 'package:littera/data/repositories/settings_repository.dart';
import 'package:littera/features/backup/backup_service.dart';
import 'package:littera/features/library/import/pdf_cover_renderer.dart';

/// Inicializa Hive en una carpeta temporal (una vez por archivo de test).
Future<Directory> initTestHive() async {
  final dir = await Directory.systemTemp.createTemp('littera_test');
  await initHive(path: dir.path);
  return dir;
}

var _boxCounter = 0;

/// Box en memoria: sin E/S de disco, válida dentro de `testWidgets`.
Future<Box<T>> memoryBox<T>() =>
    Hive.openBox<T>('mem_${_boxCounter++}', bytes: Uint8List(0));

/// Almacén de archivos en memoria.
class MemoryFileStore implements FileStore {
  final files = <String, Uint8List>{};

  @override
  Future<String> write(FileArea area, String fileName, Uint8List bytes) async {
    final ref = FileStore.refFor(area, fileName);
    files[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async => files[ref];

  @override
  Future<void> delete(String ref) async => files.remove(ref);

  @override
  ImageProvider? image(String ref) =>
      files[ref] == null ? null : MemoryImage(files[ref]!);
}

class FakePdfCoverRenderer implements PdfCoverRenderer {
  FakePdfCoverRenderer({this.result, this.fail = false});
  final Uint8List? result;
  final bool fail;
  int calls = 0;

  @override
  Future<Uint8List?> renderFirstPage(Uint8List pdfBytes) async {
    calls++;
    if (fail) throw Exception('pdfium no disponible');
    return result;
  }
}

/// Todo lo necesario para montar la app en un test.
class TestEnv {
  TestEnv._(this.settings, this.books, this.shelves, this.files, this.meta);

  final Box<AppSettings> settings;
  final Box<Book> books;
  final Box<Shelf> shelves;
  final MemoryFileStore files;
  final Box<dynamic> meta;

  static Future<TestEnv> create() async => TestEnv._(
    await memoryBox<AppSettings>(),
    await memoryBox<Book>(),
    await memoryBox<Shelf>(),
    MemoryFileStore(),
    await memoryBox<dynamic>(),
  );

  LibraryRepository get repository =>
      LibraryRepository(books: books, shelves: shelves, files: files);

  List<Override> get overrides => [
    settingsBoxProvider.overrideWithValue(settings),
    booksBoxProvider.overrideWithValue(books),
    shelvesBoxProvider.overrideWithValue(shelves),
    fileStoreProvider.overrideWithValue(files),
    metaBoxProvider.overrideWithValue(meta),
    pdfCoverRendererProvider.overrideWithValue(FakePdfCoverRenderer()),
  ];
}

Book testBook({
  String id = 'b1',
  String title = 'Libro de prueba',
  String author = 'Autora',
  ReadingStatus status = ReadingStatus.toRead,
  List<String> shelfIds = const [],
  DateTime? addedAt,
  double progress = 0,
}) => Book(
  id: id,
  title: title,
  author: author,
  format: BookFormat.epub,
  fileRef: 'books/$id.epub',
  originalFileName: '$id.epub',
  fileSize: 1024,
  contentHash: 'hash-$id',
  addedAt: addedAt ?? DateTime(2026, 1, 1),
  status: status,
  shelfIds: shelfIds,
  progress: progress,
);

/// PNG de color sólido.
Uint8List pngBytes({int width = 300, int height = 300}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(201, 164, 92));
  return img.encodePng(image);
}

Uint8List buildZip(
  Map<String, String> textFiles, {
  Map<String, Uint8List>? binary,
}) {
  final archive = Archive();
  textFiles.forEach(
    (name, content) =>
        archive.addFile(ArchiveFile.bytes(name, utf8.encode(content))),
  );
  binary?.forEach(
    (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
  );
  return ZipEncoder().encodeBytes(archive);
}

/// EPUB mínimo. [epub3] usa `properties="cover-image"`; si no, `<meta name="cover">`.
Uint8List buildEpub({
  String? title = 'El nombre del viento',
  String? author = 'Patrick Rothfuss',
  bool withCover = true,
  bool epub3 = true,
}) {
  final cover = withCover
      ? (epub3
            ? '<item id="img" href="images/portada%201.png" media-type="image/png" properties="cover-image"/>'
            : '<item id="cover-img" href="images/portada%201.png" media-type="image/png"/>')
      : '';
  final meta = withCover && !epub3
      ? '<meta name="cover" content="cover-img"/>'
      : '';
  return buildZip({
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="${epub3 ? '3.0' : '2.0'}">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '${title == null ? '' : '<dc:title>$title</dc:title>'}'
        '${author == null ? '' : '<dc:creator>$author</dc:creator>'}'
        '$meta</metadata>'
        '<manifest><item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>$cover</manifest>'
        '<spine><itemref idref="c1"/></spine></package>',
    'OEBPS/c1.xhtml': '<html><body><p>Hola</p></body></html>',
  }, binary: withCover ? {'OEBPS/images/portada 1.png': pngBytes()} : null);
}

Uint8List buildDocx({String? title = 'Mi novela', String? author = 'Ana'}) =>
    buildZip({
      '[Content_Types].xml': '<Types/>',
      'word/document.xml': '<w:document/>',
      'docProps/core.xml':
          '<?xml version="1.0"?><cp:coreProperties '
          'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/">'
          '${title == null ? '' : '<dc:title>$title</dc:title>'}'
          '${author == null ? '' : '<dc:creator>$author</dc:creator>'}'
          '</cp:coreProperties>',
    });

final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%fake pdf\n'));
