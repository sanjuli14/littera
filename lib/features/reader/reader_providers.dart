import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/file_store.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import 'document/docx_parser.dart';
import 'document/epub_parser.dart';
import 'document/reader_document.dart';

/// Posición guardada en `Book.position`.
/// - Documentos fluidos: `b:<índice de bloque>`
/// - PDF: `p:<número de página>`
sealed class ReadingPosition {
  const ReadingPosition();

  static ReadingPosition? parse(String? raw) {
    if (raw == null || raw.length < 3) return null;
    final value = int.tryParse(raw.substring(2));
    if (value == null || value < 0) return null;
    return switch (raw.substring(0, 2)) {
      'b:' => BlockPosition(value),
      'p:' => PagePosition(value),
      _ => null,
    };
  }

  String encode();
}

class BlockPosition extends ReadingPosition {
  const BlockPosition(this.index);
  final int index;
  @override
  String encode() => 'b:$index';
}

class PagePosition extends ReadingPosition {
  const PagePosition(this.page);
  final int page;
  @override
  String encode() => 'p:$page';
}

/// Bytes del archivo del libro.
final bookBytesProvider = FutureProvider.autoDispose.family<Uint8List, String>((
  ref,
  bookId,
) async {
  final book = ref.read(libraryRepositoryProvider).getBook(bookId);
  if (book == null) throw StateError('El libro ya no existe');
  final bytes = await ref.read(fileStoreProvider).read(book.fileRef);
  if (bytes == null) {
    throw StateError('No se encontró el archivo del libro');
  }
  return bytes;
});

typedef DocumentParser = Future<ReaderDocument> Function(
  BookFormat format,
  Uint8List bytes,
);

/// Convierte el archivo en bloques en un isolate aparte (no bloquea la UI).
/// Se sobrescribe en tests con una versión síncrona.
final documentParserProvider = Provider<DocumentParser>(
  (ref) =>
      (format, bytes) => switch (format) {
        BookFormat.epub => compute(parseEpub, bytes),
        BookFormat.docx => compute(parseDocx, bytes),
        BookFormat.pdf => throw UnsupportedError('El PDF usa su propio visor'),
      },
);

final readerDocumentProvider = FutureProvider.autoDispose
    .family<ReaderDocument, String>((ref, bookId) async {
      final book = ref.read(libraryRepositoryProvider).getBook(bookId);
      if (book == null) throw StateError('El libro ya no existe');
      final bytes = await ref.watch(bookBytesProvider(bookId).future);
      return ref.read(documentParserProvider)(book.format, bytes);
    });
