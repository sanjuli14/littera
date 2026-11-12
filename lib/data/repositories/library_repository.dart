import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/file_store.dart';
import '../../core/utils/box_stream.dart';
import '../../features/library/import/cover_processor.dart';
import '../hive/hive_setup.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../models/shelf.dart';
import 'highlights_repository.dart';

/// Acceso a libros y estantes guardados en Hive.
class LibraryRepository {
  LibraryRepository({
    required this.books,
    required this.shelves,
    required this.files,
    this.highlights,
  });

  /// Subrayados (se borran junto con su libro).
  final Box<Highlight>? highlights;

  final Box<Book> books;
  final Box<Shelf> shelves;
  final FileStore files;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- Libros

  Stream<List<Book>> watchBooks() =>
      watchBox(books, () => books.values.toList());

  Book? getBook(String id) => books.get(id);

  Book? findByHash(String hash) =>
      books.values.where((b) => b.contentHash == hash).firstOrNull;

  Future<void> saveBook(Book book) => books.put(book.id, book);

  /// Versión más reciente guardada (la que recibe la UI puede estar vieja).
  Book _latest(Book book) => books.get(book.id) ?? book;

  Future<void> updateDetails(Book book, {String? title, String? author}) =>
      saveBook(_latest(book).copyWith(title: title, author: author));

  Future<void> setStatus(Book book, ReadingStatus status) =>
      saveBook(_withStatus(_latest(book), status));

  /// Cambia el estado manteniendo la fecha de terminado coherente.
  Book _withStatus(Book book, ReadingStatus status) {
    if (status == book.status) return book;
    return status == ReadingStatus.finished
        ? book.copyWith(status: status, finishedAt: DateTime.now())
        : book.copyWith(status: status, clearFinishedAt: true);
  }

  /// Al abrir un libro: fecha de última lectura y, si estaba
  /// "Por leer", pasa a "Leyendo".
  Future<Book> markOpened(Book book) async {
    final current = _latest(book);
    final updated = current.copyWith(
      lastOpenedAt: DateTime.now(),
      status: current.status == ReadingStatus.toRead
          ? ReadingStatus.reading
          : current.status,
    );
    await saveBook(updated);
    return updated;
  }

  /// Guarda la posición exacta y el progreso (0–1). Lee la versión más
  /// reciente del libro para no pisar cambios hechos en otra pantalla.
  Future<void> saveProgress(String bookId, String position, double progress) {
    final latest = getBook(bookId);
    if (latest == null) return Future.value();
    return saveBook(
      latest.copyWith(position: position, progress: progress.clamp(0, 1)),
    );
  }

  Future<void> markFinished(String bookId) {
    final latest = getBook(bookId);
    if (latest == null) return Future.value();
    return saveBook(
      _withStatus(latest, ReadingStatus.finished).copyWith(progress: 1),
    );
  }

  /// Valoración de 0 (sin valorar) a 5. Tocar la misma estrella la quita.
  Future<void> setRating(Book book, int stars) {
    final current = _latest(book);
    final value = stars == current.rating ? 0 : stars.clamp(0, 5);
    return saveBook(current.copyWith(rating: value));
  }

  Future<void> toggleShelf(Book book, String shelfId) {
    final current = _latest(book);
    final ids = [...current.shelfIds];
    ids.contains(shelfId) ? ids.remove(shelfId) : ids.add(shelfId);
    return saveBook(current.copyWith(shelfIds: ids));
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
    final current = _latest(book);
    final old = current.coverRef;
    await saveBook(current.copyWith(coverRef: ref, hasCustomCover: custom));
    if (old != null && old != ref) await files.delete(old);
    return true;
  }

  /// Quita la carátula: se mostrará la generada.
  Future<void> removeCover(Book book) async {
    final current = _latest(book);
    final old = current.coverRef;
    await saveBook(current.copyWith(clearCover: true, hasCustomCover: false));
    if (old != null) await files.delete(old);
  }

  /// Elimina el libro, su archivo, su carátula y sus subrayados.
  Future<void> deleteBook(Book book) async {
    await books.delete(book.id);
    final hl = highlights;
    if (hl != null) {
      await hl.deleteAll(
        hl.values.where((h) => h.bookId == book.id).map((h) => h.id).toList(),
      );
    }
    await files.delete(book.fileRef);
    if (book.coverRef != null) await files.delete(book.coverRef!);
  }

  // -------------------------------------------------------------- Estantes

  Stream<List<Shelf>> watchShelves() => watchBox(shelves, _sortedShelves);

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
    highlights: ref.watch(highlightsBoxProvider),
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
