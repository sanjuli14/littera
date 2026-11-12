import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/storage/file_store.dart';
import '../../../data/models/book.dart';
import '../../../data/repositories/library_repository.dart';
import 'book_metadata.dart';
import 'pdf_cover_renderer.dart';

/// Error al importar, con un mensaje para mostrar al usuario.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Extensiones que ofrece el selector de archivos.
const importableExtensions = ['epub', 'pdf', 'docx', 'doc'];

class BookImporter {
  BookImporter({
    required this.repository,
    required this.files,
    required this.pdfCovers,
  });

  final LibraryRepository repository;
  final FileStore files;
  final PdfCoverRenderer pdfCovers;
  static const _uuid = Uuid();

  /// Importa un archivo y lo guarda en la biblioteca.
  Future<Book> importBytes(String fileName, Uint8List bytes) async {
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');

    if (ext == 'doc') {
      throw const ImportException(
        'El formato .doc antiguo no es compatible. Ábrelo en Word, '
        'LibreOffice o Google Docs y guárdalo como .docx.',
      );
    }
    final format = BookFormat.fromExtension(ext);
    if (format == null) {
      throw ImportException('Formato no compatible: .$ext');
    }
    if (bytes.isEmpty) throw const ImportException('El archivo está vacío.');

    final validSignature = format == BookFormat.pdf
        ? looksLikePdf(bytes)
        : looksLikeZip(bytes);
    if (!validSignature) {
      throw ImportException(
        'El archivo no parece un ${format.label} válido o está dañado.',
      );
    }

    final hash = sha1.convert(bytes).toString();
    final existing = repository.findByHash(hash);
    if (existing != null) {
      throw ImportException(
        'Ya está en tu biblioteca como "${existing.title}".',
      );
    }

    final meta = await _readMetadata(format, bytes);
    final id = _uuid.v4();
    final fileRef = await files.write(FileArea.books, '$id.$ext', bytes);

    final book = Book(
      id: id,
      title: meta.title ?? titleFromFileName(fileName),
      author: meta.author ?? '',
      format: format,
      fileRef: fileRef,
      originalFileName: fileName,
      fileSize: bytes.length,
      contentHash: hash,
      addedAt: DateTime.now(),
    );
    await repository.saveBook(book);

    final cover = meta.coverBytes;
    if (cover != null) {
      await repository.setCover(book, cover, custom: false);
    }
    return repository.getBook(id)!;
  }

  Future<BookMetadata> _readMetadata(BookFormat format, Uint8List bytes) async {
    switch (format) {
      case BookFormat.epub:
        return compute(parseEpubMetadata, bytes);
      case BookFormat.docx:
        return compute(parseDocxMetadata, bytes);
      case BookFormat.pdf:
        try {
          return BookMetadata(
            coverBytes: await pdfCovers.renderFirstPage(bytes),
          );
        } catch (e) {
          debugPrint('No se pudo generar la carátula del PDF: $e');
          return const BookMetadata();
        }
    }
  }
}

final bookImporterProvider = Provider<BookImporter>(
  (ref) => BookImporter(
    repository: ref.watch(libraryRepositoryProvider),
    files: ref.watch(fileStoreProvider),
    pdfCovers: ref.watch(pdfCoverRendererProvider),
  ),
);
