import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/text_utils.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Qué se está mostrando en la biblioteca.
sealed class LibraryFilter {
  const LibraryFilter();
}

class AllBooks extends LibraryFilter {
  const AllBooks();
  @override
  bool operator ==(Object other) => other is AllBooks;
  @override
  int get hashCode => 0;
}

class ByStatus extends LibraryFilter {
  const ByStatus(this.status);
  final ReadingStatus status;
  @override
  bool operator ==(Object other) => other is ByStatus && other.status == status;
  @override
  int get hashCode => status.hashCode;
}

class ByShelf extends LibraryFilter {
  const ByShelf(this.shelfId);
  final String shelfId;
  @override
  bool operator ==(Object other) =>
      other is ByShelf && other.shelfId == shelfId;
  @override
  int get hashCode => shelfId.hashCode;
}

class OwnWorks extends LibraryFilter {
  const OwnWorks();
  @override
  bool operator ==(Object other) => other is OwnWorks;
  @override
  int get hashCode => 1;
}

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() {
    // Si se borra el estante seleccionado, volver a "Todos".
    ref.listen(shelvesProvider, (_, next) {
      final current = state;
      final shelves = next.value;
      if (current is ByShelf &&
          shelves != null &&
          shelves.every((s) => s.id != current.shelfId)) {
        state = const AllBooks();
      }
    });
    return const AllBooks();
  }

  void select(LibraryFilter filter) => state = filter;
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
      LibraryFilterNotifier.new,
    );

class SearchQueryNotifier extends Notifier<String?> {
  /// `null` = buscador cerrado.
  @override
  String? build() => null;

  void open() => state = '';
  void close() => state = null;
  void update(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String?>(
  SearchQueryNotifier.new,
);

bool matchesFilter(Book book, LibraryFilter filter) => switch (filter) {
  AllBooks() => true,
  ByStatus(:final status) => book.status == status,
  ByShelf(:final shelfId) => book.shelfIds.contains(shelfId),
  OwnWorks() => book.isOwnWork,
};

/// Libros visibles tras aplicar filtro, búsqueda y orden.
final visibleBooksProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  final query = normalizeForSearch(ref.watch(searchQueryProvider) ?? '');
  final sort = ref.watch(settingsProvider.select((s) => s.librarySort));

  return ref.watch(booksProvider).whenData((books) {
    final visible = books.where((b) {
      if (!matchesFilter(b, filter)) return false;
      if (query.isEmpty) return true;
      return normalizeForSearch('${b.title} ${b.author}').contains(query);
    }).toList();
    visible.sort(_comparator(sort));
    return visible;
  });
});

int Function(Book, Book) _comparator(LibrarySort sort) => switch (sort) {
  LibrarySort.recentlyAdded => (a, b) => b.addedAt.compareTo(a.addedAt),
  LibrarySort.recentlyOpened => (a, b) {
    final aDate = a.lastOpenedAt ?? a.addedAt;
    final bDate = b.lastOpenedAt ?? b.addedAt;
    return bDate.compareTo(aDate);
  },
  LibrarySort.title => (a, b) => normalizeForSearch(
    a.title,
  ).compareTo(normalizeForSearch(b.title)),
  LibrarySort.author => (a, b) {
    final byAuthor = normalizeForSearch(a.author)
        .compareTo(normalizeForSearch(b.author));
    return byAuthor != 0
        ? byAuthor
        : normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title));
  },
};

/// Cantidad de libros por filtro (para los chips).
final filterCountsProvider = Provider<Map<LibraryFilter, int>>((ref) {
  final books = ref.watch(booksProvider).value ?? const <Book>[];
  final shelves = ref.watch(shelvesProvider).value ?? const [];
  return {
    const AllBooks(): books.length,
    for (final s in ReadingStatus.values)
      ByStatus(s): books.where((b) => b.status == s).length,
    for (final shelf in shelves)
      ByShelf(shelf.id): books
          .where((b) => b.shelfIds.contains(shelf.id))
          .length,
    const OwnWorks(): books.where((b) => b.isOwnWork).length,
  };
});
