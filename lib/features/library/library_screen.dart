import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/littera_logo.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../backup/backup_reminder.dart';
import 'library_actions.dart';
import 'library_providers.dart';
import 'widgets/book_tiles.dart';
import 'widgets/home_sections.dart';
import 'widgets/shelf_filter_bar.dart';

/// Biblioteca como "Inicio": buscador, pestañas, "Continúa leyendo",
/// carruseles y la colección completa.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(booksProvider);
    final hasBooks = allBooks.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: _LibraryAppBar(showTools: hasBooks),
      floatingActionButton: hasBooks
          ? FloatingActionButton.extended(
              onPressed: () => importBooks(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Importar'),
            )
          : null,
      body: allBooks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar: $e')),
        data: (books) => books.isEmpty
            ? EmptyState(
                icon: const LitteraLogo(size: 96),
                title: 'Tu biblioteca está vacía',
                message:
                    'Importa libros EPUB, PDF o DOCX para empezar a leer. '
                    'Se guardan solo en este dispositivo.',
                action: FilledButton.icon(
                  onPressed: () => importBooks(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Importar libro'),
                ),
              )
            : _LibraryHome(books: books),
      ),
    );
  }
}

class _LibraryAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _LibraryAppBar({required this.showTools});

  final bool showTools;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return AppBar(
      title: const Row(
        children: [
          LitteraLogo(size: 34),
          SizedBox(width: 12),
          Flexible(child: Text('Biblioteca', overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: showTools
          ? [
              IconButton(
                icon: const Icon(Icons.insights_outlined),
                tooltip: 'Estadísticas',
                onPressed: () => context.push(Routes.stats),
              ),
              PopupMenuButton<LibrarySort>(
                icon: const Icon(Icons.sort),
                tooltip: 'Ordenar',
                initialValue: settings.librarySort,
                onSelected: notifier.setLibrarySort,
                itemBuilder: (_) => [
                  for (final sort in LibrarySort.values)
                    CheckedPopupMenuItem(
                      value: sort,
                      checked: sort == settings.librarySort,
                      child: Text(sort.label),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(
                  settings.libraryGridView
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined,
                ),
                tooltip: settings.libraryGridView
                    ? 'Ver como lista'
                    : 'Ver como cuadrícula',
                onPressed: () =>
                    notifier.setLibraryGridView(!settings.libraryGridView),
              ),
              const SizedBox(width: 4),
            ]
          : null,
    );
  }
}

/// Buscador blanco tipo píldora con sombra suave.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _controller = TextEditingController(
    text: ref.read(searchQueryProvider) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final query = ref.watch(searchQueryProvider) ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: ref.read(searchQueryProvider.notifier).update,
          decoration: InputDecoration(
            hintText: 'Buscar por título o autor',
            fillColor: dark ? theme.colorScheme.surfaceContainer : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            suffixIcon: query.isEmpty
                ? const Icon(Icons.search)
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Borrar búsqueda',
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).update('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _LibraryHome extends ConsumerStatefulWidget {
  const _LibraryHome({required this.books});

  final List<Book> books;

  @override
  ConsumerState<_LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<_LibraryHome> {
  final _allKey = GlobalKey();

  void _scrollToAll() {
    final ctx = _allKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    final filter = ref.watch(libraryFilterProvider);
    final query = ref.watch(searchQueryProvider) ?? '';
    final visible = ref.watch(visibleBooksProvider).value ?? const <Book>[];
    final grid = ref.watch(settingsProvider.select((s) => s.libraryGridView));
    final filterNotifier = ref.read(libraryFilterProvider.notifier);

    // Las secciones de "Inicio" solo en Todos y sin búsqueda.
    final showHome = filter is AllBooks && query.isEmpty;

    final opened = books.where((b) => b.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    final hero = opened
        .where((b) => b.status == ReadingStatus.reading)
        .firstOrNull;
    final reading = opened
        .where((b) => b.status == ReadingStatus.reading && b != hero)
        .toList();
    final recent = [...books]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final ownWorks = books.where((b) => b.isOwnWork).toList();

    void open(Book book) => context.push(Routes.book(book.id));

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _SearchField()),
        const SliverToBoxAdapter(child: BackupReminder()),
        const SliverToBoxAdapter(child: ShelfFilterBar()),
        if (showHome) ...[
          if (hero != null)
            SliverToBoxAdapter(child: ContinueReadingCard(book: hero)),
          if (reading.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Leyendo ahora',
                onSeeAll: () => filterNotifier.select(
                  const ByStatus(ReadingStatus.reading),
                ),
              ),
            ),
            SliverToBoxAdapter(child: BookCarousel(books: reading)),
          ],
          if (books.length > 3) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Añadidos recientemente',
                onSeeAll: _scrollToAll,
              ),
            ),
            SliverToBoxAdapter(
              child: BookCarousel(books: recent.take(10).toList()),
            ),
          ],
          if (ownWorks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Mis obras',
                onSeeAll: () => filterNotifier.select(const OwnWorks()),
              ),
            ),
            SliverToBoxAdapter(child: BookCarousel(books: ownWorks)),
          ],
          SliverToBoxAdapter(
            key: _allKey,
            child: const SectionHeader(title: 'Toda tu biblioteca'),
          ),
        ],
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icon(
                query.isNotEmpty ? Icons.search_off : Icons.shelves,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              title: query.isNotEmpty
                  ? 'Sin resultados'
                  : 'Este estante está vacío',
              message: query.isNotEmpty
                  ? 'Prueba con otro título o autor.'
                  : 'Abre un libro y añádelo desde su ficha.',
            ),
          )
        else if (grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  // Alto según el tamaño de letra del sistema.
                  mainAxisExtent: BookGridTile.extentFor(
                    context,
                    constraints.crossAxisExtent,
                  ),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => BookGridTile(
                    book: visible[i],
                    onTap: () => open(visible[i]),
                  ),
                  childCount: visible.length,
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (_, i) =>
                BookListTile(book: visible[i], onTap: () => open(visible[i])),
          ),
        // Espacio para el botón flotante.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}
