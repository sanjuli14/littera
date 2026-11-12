import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/file_store.dart';
import '../../features/library/import/cover_processor.dart';
import '../hive/hive_setup.dart';
import '../models/book.dart';
import '../models/shelf.dart';

/// Acceso a libros y estantes guardados en Hive.
class LibraryRepository {
  LibraryRepository({
    required this.books,
    required this.shelves,
    required this.files,
  });

  final Box<Book> books;
  final Box<Shelf> shelves;
  final FileStore files;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- Libros

  Stream<List<Book>> watchBooks() async* {
    yield books.values.toList();
    yield* books.watch().map((_) => books.values.toList());
  }

  Book? getBook(String id) => books.get(id);

  Book? findByHash(String hash) =>
      books.values.where((b) => b.contentHash == hash).firstOrNull;

  Future<void> saveBook(Book book) => books.put(book.id, book);

  Future<void> updateDetails(Book book, {String? title, String? author}) =>
      saveBook(book.copyWith(title: title, author: author));

  Future<void> setStatus(Book book, ReadingStatus status) =>
      saveBook(book.copyWith(status: status));

  Future<void> toggleShelf(Book book, String shelfId) {
    final ids = [...book.shelfIds];
    ids.contains(shelfId) ? ids.remove(shelfId) : ids.add(shelfId);
    return saveBook(book.copyWith(shelfIds: ids));
  }

  /// Guarda una carátula nueva (ya recortada o no). Devuelve `false` si la
  /// imagen no es válida.
  Future<bool> setCover(
    Book book,
    Uint8List imageBytes, {
    bool custom = true,
  }) async {
    final processed = await processCover(imageBytes);
    if (processed == null) return false;
    // Nombre con marca de tiempo: evita que se muestre la imagen en caché.
    final ref = await files.write(
      FileArea.covers,
      '${book.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      processed,
    );
    final old = book.coverRef;
    await saveBook(book.copyWith(coverRef: ref, hasCustomCover: custom));
    if (old != null && old != ref) await files.delete(old);
    return true;
  }

  /// Quita la carátula: se mostrará la generada.
  Future<void> removeCover(Book book) async {
    final old = book.coverRef;
    await saveBook(book.copyWith(clearCover: true, hasCustomCover: false));
    if (old != null) await files.delete(old);
  }

  /// Elimina el libro, su archivo y su carátula.
  Future<void> deleteBook(Book book) async {
    await books.delete(book.id);
    await files.delete(book.fileRef);
    if (book.coverRef != null) await files.delete(book.coverRef!);
  }

  // -------------------------------------------------------------- Estantes

  Stream<List<Shelf>> watchShelves() async* {
    yield _sortedShelves();
    yield* shelves.watch().map((_) => _sortedShelves());
  }

  List<Shelf> _sortedShelves() =>
      shelves.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  /// Crea un estante. Devuelve `null` si ya existe uno con ese nombre.
  Future<Shelf?> createShelf(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _nameTaken(clean)) return null;
    final nextOrder = shelves.values.fold<int>(
      0,
      (max, s) => s.order >= max ? s.order + 1 : max,
    );
    final shelf = Shelf(
      id: _uuid.v4(),
      name: clean,
      order: nextOrder,
      createdAt: DateTime.now(),
    );
    await shelves.put(shelf.id, shelf);
    return shelf;
  }

  Future<bool> renameShelf(Shelf shelf, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _nameTaken(clean, except: shelf.id)) return false;
    await shelves.put(shelf.id, shelf.copyWith(name: clean));
    return true;
  }

  /// Borra el estante (los libros se quedan en la biblioteca).
  Future<void> deleteShelf(Shelf shelf) async {
    for (final book in books.values.where(
      (b) => b.shelfIds.contains(shelf.id),
    )) {
      await saveBook(
        book.copyWith(
          shelfIds: book.shelfIds.where((id) => id != shelf.id).toList(),
        ),
      );
    }
    await shelves.delete(shelf.id);
  }

  bool _nameTaken(String name, {String? except}) => shelves.values.any(
    (s) => s.id != except && s.name.toLowerCase() == name.toLowerCase(),
  );
}

final booksBoxProvider = Provider<Box<Book>>(
  (ref) => Hive.box<Book>(HiveBoxes.books),
);

final shelvesBoxProvider = Provider<Box<Shelf>>(
  (ref) => Hive.box<Shelf>(HiveBoxes.shelves),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    books: ref.watch(booksBoxProvider),
    shelves: ref.watch(shelvesBoxProvider),
    files: ref.watch(fileStoreProvider),
  ),
);

final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchBooks(),
);

final shelvesProvider = StreamProvider<List<Shelf>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchShelves(),
);

/// Un libro concreto, reactivo a cambios.
final bookProvider = Provider.family<Book?, String>((ref, id) {
  final books = ref.watch(booksProvider).value ?? const [];
  return books.where((b) => b.id == id).firstOrNull;
});
