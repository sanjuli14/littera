import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/empty_state.dart';
import '../library/widgets/book_cover.dart';
import '../library/widgets/home_sections.dart' show SectionHeader;
import 'explore_providers.dart';
import 'gutenberg_book.dart';

/// Explorar: libros gratis de dominio público (Project Gutenberg) para
/// descargar a la biblioteca.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _controller = TextEditingController();

  /// Búsqueda enviada (no se consulta en cada letra).
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) => setState(() => _query = text.trim());

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Sobre estos libros',
            onPressed: () => _showAbout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _SearchBox(
            controller: _controller,
            onSubmitted: _submit,
            onClear: _clear,
          ),
          const _LanguageChips(),
          Expanded(
            child: _query.isEmpty
                ? const _SectionsList()
                : BrowseGrid(query: (search: _query, topic: null)),
          ),
        ],
      ),
    );
  }
}

void _showAbout(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Libros de dominio público'),
    content: const Text(
      'Estos libros vienen de Project Gutenberg: clásicos cuyos derechos de '
      'autor ya caducaron, gratis y legales. Al descargar uno se añade a tu '
      'biblioteca como cualquier EPUB.\n\n'
      'Explorar es la única parte de Littera que se conecta a internet: '
      'solo envía lo que buscas, nunca datos de tu biblioteca.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Entendido'),
      ),
    ],
  ),
);

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: 'Buscar clásicos por título o autor',
              fillColor: dark
                  ? theme.colorScheme.surfaceContainer
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              suffixIcon: value.text.isEmpty
                  ? IconButton(
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Buscar',
                      onPressed: () => onSubmitted(value.text),
                    )
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Borrar búsqueda',
                      onPressed: onClear,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChips extends ConsumerWidget {
  const _LanguageChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(exploreLanguageProvider);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final (code, label) in exploreLanguages)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == code,
                onSelected: (_) =>
                    ref.read(exploreLanguageProvider.notifier).set(code),
              ),
            ),
        ],
      ),
    );
  }
}

/// Portada: una fila por tema. Se cargan al hacerse visibles.
class _SectionsList extends StatelessWidget {
  const _SectionsList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: exploreSections.length,
      itemBuilder: (context, i) {
        final (title, topic) = exploreSections[i];
        return _SectionRow(title: title, topic: topic);
      },
    );
  }
}

class _SectionRow extends ConsumerWidget {
  const _SectionRow({required this.title, required this.topic});

  final String title;
  final String? topic;

  static const _height = 246.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(exploreSectionProvider(topic));
    final theme = Theme.of(context);

    Widget body = section.when(
      skipLoadingOnReload: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(exploreSectionProvider(topic)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (page) => page.results.isEmpty
          ? Center(
              child: Text(
                'No hay libros de este tema en este idioma.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: page.results.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => SizedBox(
                width: 120,
                child: ExploreBookCard(book: page.results[i]),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          onSeeAll: section.hasValue && section.value!.results.isNotEmpty
              ? () => context.push(
                  Routes.exploreTopic(topic: topic, title: title),
                )
              : null,
        ),
        SizedBox(height: _height, child: body),
      ],
    );
  }
}

/// Carátula, título y autor; abre la ficha.
class ExploreBookCard extends StatelessWidget {
  const ExploreBookCard({super.key, required this.book});

  final GutenbergBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = book.coverUrl;
    return Semantics(
      button: true,
      label: '${book.title}, de ${book.authorLine}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.exploreBook(book.id), extra: book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(
              coverRef: null,
              image: cover == null ? null : NetworkImage(cover),
              title: book.title,
              author: book.authorLine,
              label: 'GRATIS',
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              book.authorLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuadrícula paginada de una búsqueda o de un tema.
class BrowseGrid extends ConsumerWidget {
  const BrowseGrid({super.key, required this.query});

  final BrowseQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseProvider(query));
    final notifier = ref.read(browseProvider(query).notifier);
    final theme = Theme.of(context);

    if (state.items.isEmpty) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.error != null) {
        return EmptyState(
          icon: Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          title: 'No se pudo cargar',
          message: state.error!,
          action: FilledButton(
            onPressed: notifier.retry,
            child: const Text('Reintentar'),
          ),
        );
      }
      return EmptyState(
        icon: Icon(
          Icons.search_off_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        title: 'Sin resultados',
        message:
            'Prueba con otro título, con el apellido del autor o con '
            'otro idioma.',
      );
    }

    return NotificationListener<ScrollNotification>(
      // Carga la página siguiente al acercarse al final.
      onNotification: (n) {
        if (n.metrics.extentAfter < 600 && state.error == null) {
          notifier.loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                state.count == 1 ? '1 libro' : '${state.count} libros',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.48,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, i) =>
                  ExploreBookCard(book: state.items[i]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Center(
                child: state.loading
                    ? const CircularProgressIndicator()
                    : state.error != null
                    ? Column(
                        children: [
                          Text(state.error!, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: notifier.retry,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : state.hasMore
                    ? OutlinedButton(
                        onPressed: notifier.loadMore,
                        child: const Text('Cargar más'),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ver todo" de una sección.
class ExploreTopicScreen extends StatelessWidget {
  const ExploreTopicScreen({super.key, required this.title, this.topic});

  final String title;
  final String? topic;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: BrowseGrid(query: (search: null, topic: topic)),
  );
}
