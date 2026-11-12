import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/models/book.dart';
import '../../data/models/highlight.dart';
import '../../data/repositories/highlights_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'reader_palette.dart';
import 'reader_providers.dart';
import 'reader_screen.dart';
import 'widgets/reader_chrome.dart';
import 'widgets/highlight_sheets.dart';
import 'widgets/reader_sheets.dart';

/// Lector de PDF con pdfrx. La posición es el número de página.
class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({
    super.key,
    required this.book,
    required this.bytes,
    this.initialPage,
  });

  final Book book;
  final Uint8List bytes;
  final int? initialPage;

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView>
    with ReaderStateMixin {
  final _controller = PdfViewerController();
  late final int _initialPage;
  int _page = 1;
  int _pageCount = 0;
  double? _seekPreview;
  List<TocItem> _outline = const [];
  Timer? _saveTimer;

  @override
  String get bookId => widget.book.id;

  @override
  void initState() {
    super.initState();
    final saved = ReadingPosition.parse(widget.book.position);
    _initialPage = widget.initialPage != null && widget.initialPage! > 0
        ? widget.initialPage!
        : saved is PagePosition && saved.page > 0
        ? saved.page
        : 1;
    _page = _initialPage;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  (String, double)? currentProgress() {
    if (_pageCount == 0) return null;
    final progress = _pageCount <= 1 ? 1.0 : (_page - 1) / (_pageCount - 1);
    return (PagePosition(_page).encode(), progress);
  }

  Future<void> _onReady(PdfDocument document, PdfViewerController _) async {
    setState(() => _pageCount = document.pages.length);
    try {
      final outline = await document.loadOutline();
      final items = <TocItem>[];
      void visit(List<PdfOutlineNode> nodes, int level) {
        for (final node in nodes) {
          final page = node.dest?.pageNumber;
          if (page != null && node.title.trim().isNotEmpty) {
            items.add(TocItem(node.title.trim(), page, level: level));
          }
          visit(node.children, level + 1);
        }
      }

      visit(outline, 1);
      if (mounted) setState(() => _outline = items);
    } catch (_) {
      // Sin índice: no pasa nada.
    }
  }

  void _onPageChanged(int? page) {
    if (page == null || page == _page) return;
    readingActivity();
    setState(() => _page = page);
    if (chromeVisible) setChromeVisible(false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), saveNow);
    if (page == _pageCount) onReachedEnd();
  }

  int _pageFor(double fraction) =>
      (1 + fraction * (_pageCount - 1)).round().clamp(1, _pageCount);

  Future<void> _goTo(int page) async {
    if (!_controller.isReady) return;
    await _controller.goToPage(pageNumber: page);
  }

  // ------------------------------------------------------- Citas y notas

  HighlightsRepository get _highlights =>
      ref.read(highlightsRepositoryProvider);

  String _locationOf(Highlight h) => 'Página ${h.page ?? '?'}';

  /// "Guardar cita" desde el menú de selección del PDF.
  Future<void> _saveSelection(
    PdfTextSelectionDelegate selection,
    ReaderPalette palette,
  ) async {
    final text = (await selection.getSelectedText()).trim();
    if (text.isEmpty) return;
    final ranges = await selection.getSelectedTextRanges();
    final page = ranges.isEmpty ? _page : ranges.first.pageNumber;
    await selection.clearTextSelection();
    if (!mounted) return;
    final result = await showHighlightEditor(
      context,
      palette: palette,
      quote: text,
      location: 'Página $page',
    );
    if (result is SaveHighlight) {
      await _highlights.addPageHighlight(
        bookId: bookId,
        page: page,
        text: text,
        note: result.note,
        color: result.color,
      );
    }
  }

  Future<void> _addPageNote(ReaderPalette palette) async {
    final page = _page;
    final result = await showHighlightEditor(
      context,
      palette: palette,
      quote: '',
      location: 'Nota en la página $page',
    );
    if (result is SaveHighlight && result.note != null) {
      await _highlights.addPageHighlight(
        bookId: bookId,
        page: page,
        note: result.note,
        color: result.color,
      );
    }
  }

  Future<void> _edit(Highlight h, ReaderPalette palette) async {
    final result = await showHighlightEditor(
      context,
      palette: palette,
      quote: h.text,
      existing: h,
      location: _locationOf(h),
    );
    switch (result) {
      case SaveHighlight(:final color, :final note):
        if (h.isPageNote && note == null) {
          await _highlights.delete(h.id); // una nota vacía no tiene sentido
        } else {
          await _highlights.update(
            h.copyWith(color: color, note: note, clearNote: note == null),
          );
        }
      case DeleteHighlight():
        await _highlights.delete(h.id);
      case null:
        break;
    }
  }

  Future<void> _openNotes(ReaderPalette palette) async {
    final target = await showBookNotesSheet(
      context,
      palette: palette,
      highlights: ref.read(bookHighlightsProvider(bookId)),
      locationOf: _locationOf,
      onEdit: (h) => _edit(h, palette),
      onAddPageNote: () => _addPageNote(palette),
    );
    if (target?.page != null) await _goTo(target!.page!);
  }

  Future<void> _openToc(ReaderPalette palette) async {
    var currentIndex = -1;
    for (var i = 0; i < _outline.length; i++) {
      if (_outline[i].target <= _page) currentIndex = i;
    }
    final target = await showTocSheet(
      context,
      palette: palette,
      items: _outline,
      currentIndex: currentIndex < 0 ? null : currentIndex,
    );
    if (target != null) await _goTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = ref.watch(
      settingsProvider.select((s) => s.readerTheme),
    );
    final palette = ReaderPalette.resolve(readerTheme, Theme.of(context));
    final shownPage = _seekPreview != null && _pageCount > 0
        ? _pageFor(_seekPreview!)
        : _page;
    final progress =
        _seekPreview ??
        (_pageCount <= 1 ? 0.0 : (_page - 1) / (_pageCount - 1));

    return ReaderChrome(
      visible: chromeVisible,
      palette: palette,
      title: widget.book.title,
      subtitle: _pageCount == 0 ? null : 'Página $shownPage de $_pageCount',
      progress: progress,
      progressLabel: _pageCount == 0
          ? 'Cargando…'
          : 'Página $shownPage de $_pageCount',
      onSeekPreview: _pageCount == 0
          ? null
          : (v) => setState(() => _seekPreview = v),
      onSeek: (v) {
        setState(() => _seekPreview = null);
        if (_pageCount > 0) _goTo(_pageFor(v));
      },
      onToc: _outline.isEmpty ? null : () => _openToc(palette),
      onNotes: () => _openNotes(palette),
      onSettings: () =>
          showReaderSettings(context, palette: palette, textOptions: false),
      child: SafeArea(
        child: PdfViewer.data(
          widget.bytes,
          sourceName: widget.book.id,
          controller: _controller,
          initialPageNumber: _initialPage,
          params: PdfViewerParams(
            backgroundColor: palette.background,
            margin: 8,
            pageDropShadow: BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            onViewerReady: _onReady,
            onPageChanged: _onPageChanged,
            customizeContextMenuItems: (params, items) {
              if (!params.textSelectionDelegate.hasSelectedText) return;
              items.insert(
                0,
                ContextMenuButtonItem(
                  label: 'Guardar cita',
                  onPressed: () {
                    params.dismissContextMenu();
                    _saveSelection(params.textSelectionDelegate, palette);
                  },
                ),
              );
            },
            onGeneralTap: (context, controller, details) {
              if (details.type == PdfViewerGeneralTapType.tap) {
                toggleChrome();
                return true;
              }
              return false;
            },
            loadingBannerBuilder: (context, _, _) =>
                const Center(child: CircularProgressIndicator()),
            errorBannerBuilder: (context, error, _, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se pudo abrir el PDF. Puede estar dañado o protegido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
