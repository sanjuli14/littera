import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gutenberg_book.dart';
import 'gutendex_client.dart';

/// Idiomas del filtro de Explorar. `null` = todos.
const exploreLanguages = <(String?, String)>[
  ('es', 'Español'),
  ('en', 'Inglés'),
  ('fr', 'Francés'),
  ('pt', 'Portugués'),
  ('it', 'Italiano'),
  (null, 'Todos'),
];

class ExploreLanguageNotifier extends Notifier<String?> {
  @override
  String? build() => 'es';

  void set(String? language) => state = language;
}

final exploreLanguageProvider =
    NotifierProvider<ExploreLanguageNotifier, String?>(
      ExploreLanguageNotifier.new,
    );

/// Secciones de la portada: título y tema de Gutenberg (sus temas están en
/// inglés). `null` = los más descargados.
const exploreSections = <(String, String?)>[
  ('Los más leídos', null),
  ('Novela', 'fiction'),
  ('Poesía', 'poetry'),
  ('Teatro', 'drama'),
  ('Cuentos', 'short stories'),
  ('Historia', 'history'),
  ('Aventuras', 'adventure'),
  ('Infantil', 'children'),
];

/// Sin reintentos automáticos: el catálogo es un servicio compartido y los
/// errores se reintentan a mano.
Duration? _noRetry(int _, Object _) => null;

/// Una sección de la portada en el idioma elegido.
final exploreSectionProvider = FutureProvider.autoDispose
    .family<GutendexPage, String?>((ref, topic) {
      final language = ref.watch(exploreLanguageProvider);
      return ref
          .watch(gutendexClientProvider)
          .books(language: language, topic: topic);
    }, retry: _noRetry);

/// Ficha de un libro cuando no se llegó desde una lista.
final gutenbergBookProvider = FutureProvider.autoDispose
    .family<GutenbergBook, int>(
      (ref, id) => ref.watch(gutendexClientProvider).book(id),
      retry: _noRetry,
    );

/// Estado de una búsqueda o de "Ver todo" de una sección.
class BrowseState {
  const BrowseState({
    this.items = const [],
    this.count = 0,
    this.next,
    this.loading = false,
    this.error,
  });

  final List<GutenbergBook> items;
  final int count;
  final String? next;
  final bool loading;
  final String? error;

  bool get hasMore => next != null;
}

/// Qué se está listando: texto buscado o tema.
typedef BrowseQuery = ({String? search, String? topic});

class BrowseNotifier extends Notifier<BrowseState> {
  BrowseNotifier(this.query);

  final BrowseQuery query;

  @override
  BrowseState build() {
    ref.watch(exploreLanguageProvider);
    Future.microtask(_loadFirst);
    return const BrowseState(loading: true);
  }

  GutendexClient get _client => ref.read(gutendexClientProvider);

  Future<void> _loadFirst() async {
    final language = ref.read(exploreLanguageProvider);
    await _load(
      () => _client.books(
        language: language,
        search: query.search,
        topic: query.topic,
      ),
      append: false,
    );
  }

  /// Vuelve a intentarlo tras un error.
  Future<void> retry() async {
    if (state.items.isEmpty) {
      state = const BrowseState(loading: true);
      await _loadFirst();
    } else {
      await loadMore();
    }
  }

  Future<void> loadMore() async {
    final next = state.next;
    if (next == null || state.loading) return;
    await _load(() => _client.page(next), append: true);
  }

  Future<void> _load(
    Future<GutendexPage> Function() fetch, {
    required bool append,
  }) async {
    final previous = state;
    state = BrowseState(
      items: previous.items,
      count: previous.count,
      next: previous.next,
      loading: true,
    );
    try {
      final page = await fetch();
      if (!ref.mounted) return;
      final seen = {for (final b in previous.items) b.id};
      state = BrowseState(
        items: append
            ? [
                ...previous.items,
                ...page.results.where((b) => !seen.contains(b.id)),
              ]
            : page.results,
        count: page.count,
        next: page.next,
      );
    } on ExploreException catch (e) {
      if (!ref.mounted) return;
      state = BrowseState(
        items: previous.items,
        count: previous.count,
        next: previous.next,
        error: e.message,
      );
    }
  }
}

final browseProvider = NotifierProvider.autoDispose
    .family<BrowseNotifier, BrowseState, BrowseQuery>(BrowseNotifier.new);
