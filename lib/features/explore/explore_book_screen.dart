import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_theme.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/repositories/library_repository.dart';
import '../library/import/book_importer.dart';
import '../library/widgets/book_cover.dart';
import 'explore_providers.dart';
import 'gutenberg_book.dart';
import 'gutendex_client.dart';

/// Nombre de cada idioma de Gutenberg (código de dos letras).
const _languageNames = {
  'es': 'Español',
  'en': 'Inglés',
  'fr': 'Francés',
  'pt': 'Portugués',
  'it': 'Italiano',
  'de': 'Alemán',
  'ca': 'Catalán',
  'gl': 'Gallego',
  'eu': 'Euskera',
  'la': 'Latín',
  'nl': 'Neerlandés',
  'fi': 'Finés',
  'el': 'Griego',
};

/// Ficha de un libro del catálogo, con su botón de descarga.
class ExploreBookScreen extends ConsumerWidget {
  const ExploreBookScreen({super.key, required this.id, this.initial});

  final int id;

  /// El libro tal como vino en la lista (evita otra consulta).
  final GutenbergBook? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = initial;
    if (known != null && known.id == id) {
      return _BookView(book: known);
    }
    final book = ref.watch(gutenbergBookProvider(id));
    return book.when(
      data: (b) => _BookView(book: b),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(gutenbergBookProvider(id)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookView extends ConsumerWidget {
  const _BookView({required this.book});

  final GutenbergBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cover = book.coverUrl;
    final languages = book.languages
        .map((l) => _languageNames[l] ?? l.toUpperCase())
        .join(', ');
    final topics = {
      ...book.bookshelves.map((s) => s.replaceFirst('Category: ', '')),
      ...book.subjects.map((s) => s.split(' -- ').first),
    }.take(10).toList();

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
        children: [
          Center(
            child: SizedBox(
              width: 160,
              child: CoverImage(
                coverRef: null,
                image: cover == null ? null : NetworkImage(cover),
                title: book.title,
                author: book.authorLine,
                label: 'GRATIS',
                semanticLabel: 'Carátula de ${book.title}',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: LitteraTheme.serif,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (book.authors.isEmpty)
            Text(
              'Anónimo',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            )
          else
            for (final author in book.authors)
              Text(
                [
                  author.displayName,
                  if (author.lifespan.isNotEmpty) '(${author.lifespan})',
                ].join(' '),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
          if (book.translators.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Traducción: '
              '${book.translators.map((t) => t.displayName).join(', ')}',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (languages.isNotEmpty)
                _InfoChip(icon: Icons.translate_rounded, label: languages),
              _InfoChip(
                icon: Icons.download_rounded,
                label: '${_compact(book.downloadCount)} descargas',
              ),
              const _InfoChip(
                icon: Icons.public_rounded,
                label: 'Dominio público',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _DownloadButton(book: book),
          if (book.summaries.isNotEmpty) ...[
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text('Sinopsis', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 2),
            Text('Generada por Project Gutenberg, en inglés.', style: muted),
            const SizedBox(height: 8),
            Text(
              book.summaries.first,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: LitteraTheme.serif,
                height: 1.5,
              ),
            ),
          ],
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text('Temas', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in topics) Chip(label: Text(t))],
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Project Gutenberg · libro n.º ${book.id}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 1234 → "1234", 45210 → "45 mil".
String _compact(int n) =>
    n >= 10000 ? '${(n / 1000).round()} mil' : n.toString();

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// "Descargar a mi biblioteca" o, si ya está, "Leer ahora".
class _DownloadButton extends ConsumerStatefulWidget {
  const _DownloadButton({required this.book});

  final GutenbergBook book;

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    final client = ref.read(gutendexClientProvider);
    try {
      final bytes = await client.downloadEpub(widget.book);
      final imported = await ref
          .read(bookImporterProvider)
          .importBytes(widget.book.fileName, bytes);
      await client.markDownloaded(widget.book.id, imported.id);
      if (mounted) showMessage(context, 'Añadido a tu biblioteca');
    } on ExploreException catch (e) {
      if (mounted) showMessage(context, e.message);
    } on ImportException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      debugPrint('Error descargando ${widget.book.id}: $e');
      if (mounted) showMessage(context, 'No se pudo añadir el libro.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se vigila la biblioteca para notar si se borró el libro descargado.
    ref.watch(booksProvider);
    final bookId = ref
        .read(gutendexClientProvider)
        .downloadedBookId(widget.book.id);
    final inLibrary =
        bookId != null &&
        ref.read(libraryRepositoryProvider).getBook(bookId) != null;

    if (inLibrary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => context.push(Routes.reader(bookId)),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Leer ahora'),
          ),
          const SizedBox(height: 6),
          Text(
            'Ya está en tu biblioteca.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    if (!widget.book.canDownload) {
      return const FilledButton(
        onPressed: null,
        child: Text('Sin versión EPUB'),
      );
    }
    return FilledButton.icon(
      onPressed: _downloading ? null : _download,
      icon: _downloading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      label: Text(_downloading ? 'Descargando…' : 'Descargar a mi biblioteca'),
    );
  }
}
