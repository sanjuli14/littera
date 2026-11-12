import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import 'library_actions.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_tiles.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider(bookId));
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Este libro ya no está en tu biblioteca'),
        ),
      );
    }

    final theme = Theme.of(context);
    final repo = ref.read(libraryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar datos',
            onPressed: () => _editDetails(context, ref, book),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (action) => switch (action) {
              'cover' => pickCustomCover(context, ref, book),
              'remove-cover' => repo.removeCover(book),
              'delete' => _delete(context, ref, book),
              _ => null,
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'cover',
                child: ListTile(
                  leading: Icon(Icons.image_outlined),
                  title: Text('Cambiar carátula'),
                ),
              ),
              if (book.coverRef != null)
                const PopupMenuItem(
                  value: 'remove-cover',
                  child: ListTile(
                    leading: Icon(Icons.hide_image_outlined),
                    title: Text('Usar carátula generada'),
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Eliminar libro'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => pickCustomCover(context, ref, book),
              child: SizedBox(
                width: 180,
                child: Stack(
                  children: [
                    Hero(
                      tag: 'cover-${book.id}',
                      child: BookCover(book: book),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: LitteraColors.tinta.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                            color: LitteraColors.pergamino,
                            semanticLabel: 'Cambiar carátula',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.author.isEmpty ? 'Autor desconocido' : book.author,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FormatBadge(format: book.format),
              if (book.isOwnWork)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LitteraColors.oro.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Obra propia',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                '${formatFileSize(book.fileSize)} · añadido el '
                '${formatDate(book.addedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push(Routes.reader(book.id)),
            icon: const Icon(Icons.menu_book),
            label: Text(
              book.progress > 0
                  ? 'Continuar · ${(book.progress * 100).round()} %'
                  : 'Leer',
            ),
          ),
          const SizedBox(height: 28),
          _SectionTitle('Estado'),
          const SizedBox(height: 8),
          SegmentedButton<ReadingStatus>(
            segments: [
              for (final s in ReadingStatus.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {book.status},
            showSelectedIcon: false,
            onSelectionChanged: (s) => repo.setStatus(book, s.first),
          ),
          const SizedBox(height: 28),
          _SectionTitle('Estantes'),
          const SizedBox(height: 8),
          _ShelfChips(book: book),
        ],
      ),
    );
  }

  Future<void> _editDetails(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditDetailsDialog(book: book),
    );
    if (result == null) return;
    final (title, author) = result;
    await ref
        .read(libraryRepositoryProvider)
        .updateDetails(
          book,
          title: title.isEmpty ? book.title : title,
          author: author,
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Book book) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar "${book.title}"?',
      message:
          'Se borrará el archivo de este dispositivo. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(libraryRepositoryProvider).deleteBook(book);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.secondary,
      ),
    );
  }
}

class _ShelfChips extends ConsumerWidget {
  const _ShelfChips({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(shelvesProvider).value ?? const [];
    final repo = ref.read(libraryRepositoryProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final shelf in shelves)
          FilterChip(
            label: Text(shelf.name),
            selected: book.shelfIds.contains(shelf.id),
            onSelected: (_) => repo.toggleShelf(book, shelf.id),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo estante'),
          onPressed: () async {
            final shelf = await createShelf(context, ref);
            if (shelf == null) return;
            final latest = repo.getBook(book.id);
            if (latest != null) await repo.toggleShelf(latest, shelf.id);
          },
        ),
      ],
    );
  }
}

class _EditDetailsDialog extends StatefulWidget {
  const _EditDetailsDialog({required this.book});
  final Book book;

  @override
  State<_EditDetailsDialog> createState() => _EditDetailsDialogState();
}

class _EditDetailsDialogState extends State<_EditDetailsDialog> {
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(text: widget.book.author);

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar datos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _author,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Autor'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (_title.text.trim(), _author.text.trim())),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
