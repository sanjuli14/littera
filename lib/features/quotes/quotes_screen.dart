import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/models/highlight.dart';
import '../../data/repositories/highlights_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../library/widgets/book_cover.dart';
import '../reader/reader_palette.dart';
import '../reader/widgets/highlight_sheets.dart';
import 'quotes_export.dart';

/// Filtros de "Mis citas".
class QuotesFilter {
  const QuotesFilter({this.query = '', this.color});
  final String query;
  final HighlightColor? color;
}

class QuotesFilterNotifier extends Notifier<QuotesFilter> {
  @override
  QuotesFilter build() => const QuotesFilter();

  void setQuery(String q) => state = QuotesFilter(query: q, color: state.color);

  void toggleColor(HighlightColor c) => state = QuotesFilter(
    query: state.query,
    color: state.color == c ? null : c,
  );
}

final quotesFilterProvider =
    NotifierProvider<QuotesFilterNotifier, QuotesFilter>(
      QuotesFilterNotifier.new,
    );

/// Citas filtradas, agrupadas por libro (libros leídos recientemente primero).
final visibleQuotesProvider = Provider<List<(Book?, List<Highlight>)>>((ref) {
  final filter = ref.watch(quotesFilterProvider);
  final all = ref.watch(allHighlightsProvider).value ?? const <Highlight>[];
  final books = {
    for (final b in ref.watch(booksProvider).value ?? const <Book>[]) b.id: b,
  };
  final query = normalizeForSearch(filter.query);

  final groups = <String, List<Highlight>>{};
  for (final h in all) {
    if (filter.color != null && h.color != filter.color) continue;
    if (query.isNotEmpty) {
      final haystack = normalizeForSearch(
        '${h.text} ${h.note ?? ''} ${books[h.bookId]?.title ?? ''} '
        '${books[h.bookId]?.author ?? ''}',
      );
      if (!haystack.contains(query)) continue;
    }
    (groups[h.bookId] ??= []).add(h);
  }

  DateTime latest(List<Highlight> list) => list
      .map((h) => h.updatedAt ?? h.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  final result = [
    for (final entry in groups.entries)
      (
        books[entry.key],
        entry.value..sort((a, b) => a.sortKey.compareTo(b.sortKey)),
      ),
  ]..sort((a, b) => latest(b.$2).compareTo(latest(a.$2)));
  return result;
});

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _markdown() => buildQuotesMarkdown(
    ref.read(allHighlightsProvider).value ?? const [],
    {for (final b in ref.read(booksProvider).value ?? const <Book>[]) b.id: b},
  );

  Future<void> _export(String action) async {
    final md = _markdown();
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: md));
      if (mounted) showMessage(context, 'Citas copiadas al portapapeles');
      return;
    }
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Guardar citas',
      fileName: 'mis-citas-littera.md',
      bytes: Uint8List.fromList(utf8.encode(md)),
      mimeType: 'text/markdown',
    );
    if ((saved != null || kIsWeb) && mounted) {
      showMessage(context, 'Citas exportadas');
    }
  }

  Future<void> _edit(Highlight h) async {
    final palette = ReaderPalette.resolve(ReaderTheme.auto, Theme.of(context));
    final result = await showHighlightEditor(
      context,
      palette: palette,
      quote: h.text,
      existing: h,
      location: highlightLocation(h).isEmpty ? null : highlightLocation(h),
    );
    final repo = ref.read(highlightsRepositoryProvider);
    switch (result) {
      case SaveHighlight(:final color, :final note):
        if (h.isPageNote && note == null) {
          await repo.delete(h.id);
        } else {
          await repo.update(
            h.copyWith(color: color, note: note, clearNote: note == null),
          );
        }
      case DeleteHighlight():
        await repo.delete(h.id);
      case null:
        break;
    }
  }

  void _open(Highlight h) {
    final target = h.blockIndex ?? h.page;
    context.push(Routes.reader(h.bookId, target: target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(allHighlightsProvider).value ?? const <Highlight>[];
    final groups = ref.watch(visibleQuotesProvider);
    final filter = ref.watch(quotesFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis citas'),
        actions: [
          if (all.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Exportar citas',
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'file',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Exportar a Markdown'),
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Copiar todo'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icon(
                Icons.format_quote,
                size: 72,
                color: LitteraColors.oro,
              ),
              title: 'Aún no tienes citas',
              message:
                  'Mientras lees, mantén pulsado un texto para subrayarlo o '
                  'añadir una nota. Aparecerán aquí.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: ref.read(quotesFilterProvider.notifier).setQuery,
                    decoration: InputDecoration(
                      hintText: 'Buscar en citas, notas o libros',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in HighlightColor.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: CircleAvatar(
                              backgroundColor: c.color,
                              radius: 7,
                            ),
                            label: Text(c.label),
                            selected: filter.color == c,
                            showCheckmark: false,
                            onSelected: (_) => ref
                                .read(quotesFilterProvider.notifier)
                                .toggleColor(c),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? const EmptyState(
                          icon: Icon(Icons.search_off, size: 56),
                          title: 'Sin resultados',
                          message: 'Prueba con otra palabra o color.',
                        )
                      : ListView(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          children: [
                            for (final (book, items) in groups) ...[
                              _BookHeader(book: book, count: items.length),
                              for (final h in items)
                                HighlightTile(
                                  highlight: h,
                                  location: highlightLocation(h),
                                  textColor: theme.colorScheme.onSurface,
                                  secondaryColor:
                                      theme.colorScheme.onSurfaceVariant,
                                  onTap: book == null ? () {} : () => _open(h),
                                  onEdit: () => _edit(h),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.book, required this.count});

  final Book? book;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (book != null)
            SizedBox(width: 32, child: BookCover(book: book!, compact: true)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book?.title ?? 'Libro eliminado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  count == 1 ? '1 cita' : '$count citas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
