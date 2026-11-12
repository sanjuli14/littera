import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/empty_state.dart';
import '../backup/backup_reminder.dart';
import '../../core/widgets/littera_logo.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'library_actions.dart';
import 'library_providers.dart';
import 'widgets/book_tiles.dart';
import 'widgets/shelf_filter_bar.dart';

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
            : const Column(
                children: [
                  BackupReminder(),
                  ShelfFilterBar(),
                  Expanded(child: _BookCollection()),
                ],
              ),
      ),
    );
  }
}

class _LibraryAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const _LibraryAppBar({required this.showTools});

  final bool showTools;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<_LibraryAppBar> createState() => _LibraryAppBarState();
}

class _LibraryAppBarState extends ConsumerState<_LibraryAppBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    if (query != null) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Cerrar búsqueda',
          onPressed: _closeSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por título o autor',
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchQueryProvider.notifier).update,
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Borrar',
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).update('');
              },
            ),
        ],
      );
    }

    return AppBar(
      title: const Row(
        children: [
          LitteraLogo(size: 32),
          SizedBox(width: 12),
          Flexible(child: Text('Biblioteca', overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: widget.showTools
          ? [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Buscar',
                onPressed: ref.read(searchQueryProvider.notifier).open,
              ),
              PopupMenuButton<LibrarySort>(
                icon: const Icon(Icons.sort),
                tooltip: 'Ordenar',
                initialValue: settings.librarySort,
                onSelected: settingsNotifier.setLibrarySort,
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
                onPressed: () => settingsNotifier.setLibraryGridView(
                  !settings.libraryGridView,
                ),
              ),
            ]
          : null,
    );
  }
}

class _BookCollection extends ConsumerWidget {
  const _BookCollection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(visibleBooksProvider).value ?? const <Book>[];
    final grid = ref.watch(settingsProvider.select((s) => s.libraryGridView));
    final searching = (ref.watch(searchQueryProvider) ?? '').isNotEmpty;

    if (books.isEmpty) {
      return EmptyState(
        icon: Icon(
          searching ? Icons.search_off : Icons.shelves,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        title: searching ? 'Sin resultados' : 'Este estante está vacío',
        message: searching
            ? 'Prueba con otro título o autor.'
            : 'Abre un libro y añádelo desde su ficha.',
      );
    }

    void open(Book book) => context.push(Routes.book(book.id));
    const bottomPadding = 96.0; // espacio para el botón flotante

    if (!grid) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: bottomPadding),
        itemCount: books.length,
        itemBuilder: (_, i) =>
            BookListTile(book: books[i], onTap: () => open(books[i])),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.48,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) =>
          BookGridTile(book: books[i], onTap: () => open(books[i])),
    );
  }
}
