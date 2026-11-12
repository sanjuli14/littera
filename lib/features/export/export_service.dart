import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/file_store.dart';
import '../../data/models/book.dart';
import '../../data/repositories/writing_repository.dart';
import '../library/import/book_importer.dart';
import '../library/import/cover_processor.dart';
import 'cover_renderer.dart';
import 'epub_writer.dart';
import 'manuscript_compiler.dart';
import 'pdf_writer.dart';

enum ExportFormat {
  epub,
  pdf;

  String get label => name.toUpperCase();
}

class ExportException implements Exception {
  const ExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Archivo exportado.
class ExportedFile {
  const ExportedFile(this.fileName, this.bytes, this.format);
  final String fileName;
  final Uint8List bytes;
  final ExportFormat format;

  String get mimeType => switch (format) {
    ExportFormat.epub => 'application/epub+zip',
    ExportFormat.pdf => 'application/pdf',
  };
}

typedef FontLoader = Future<PdfFontData> Function();
typedef CoverRenderer = Future<Uint8List?> Function(
  String title,
  String author,
);

/// Fuentes Inter incluidas en la app (no hay Bold Italic: se usa Bold).
Future<PdfFontData> loadBundledFonts() async => PdfFontData(
  regular: await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  bold: await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
  italic: await rootBundle.load('assets/fonts/Inter-Italic.ttf'),
  boldItalic: await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
);

class ExportService {
  ExportService({
    required this.writing,
    required this.files,
    required this.importer,
    this.loadFonts = loadBundledFonts,
    this.renderCover = renderGeneratedCover,
  });

  final WritingRepository writing;
  final FileStore files;
  final BookImporter importer;
  final FontLoader loadFonts;
  final CoverRenderer renderCover;

  /// Genera el archivo de la obra.
  Future<ExportedFile> export(String manuscriptId, ExportFormat format) async {
    final m = writing.manuscript(manuscriptId);
    if (m == null) throw const ExportException('La obra ya no existe.');
    final book = compileManuscript(m, writing.chaptersOf(m.id));
    if (book.isEmpty) {
      throw const ExportException(
        'La obra no tiene texto todavía. Escribe al menos un capítulo.',
      );
    }

    final cover = await _cover(m.coverRef, m.title, m.author);
    final ext = format.name;
    final bytes = switch (format) {
      ExportFormat.epub => writeEpub(book, coverJpeg: cover),
      ExportFormat.pdf => await compute(
        buildPdf,
        PdfJob(book, await loadFonts(), cover),
      ),
    };
    return ExportedFile(exportFileName(m.title, ext), bytes, format);
  }

  /// Añade (o actualiza) la obra exportada en la biblioteca.
  Future<Book> addToLibrary(String manuscriptId, ExportedFile file) =>
      importer.importOwnWork(manuscriptId, file.fileName, file.bytes);

  /// Carátula en JPEG: la de la obra o una generada.
  Future<Uint8List?> _cover(
    String? coverRef,
    String title,
    String author,
  ) async {
    if (coverRef != null) {
      final stored = await files.read(coverRef);
      if (stored != null) return stored;
    }
    try {
      final png = await renderCover(title, author);
      return png == null ? null : await processCover(png);
    } catch (e) {
      debugPrint('No se pudo generar la carátula: $e');
      return null;
    }
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    writing: ref.watch(writingRepositoryProvider),
    files: ref.watch(fileStoreProvider),
    importer: ref.watch(bookImporterProvider),
  ),
);
