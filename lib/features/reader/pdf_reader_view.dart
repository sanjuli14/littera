import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/models/book.dart';
import '../../data/repositories/settings_repository.dart';
import 'reader_palette.dart';
import 'reader_providers.dart';
import 'reader_screen.dart';
import 'widgets/reader_chrome.dart';
import 'widgets/reader_sheets.dart';

/// Lector de PDF con pdfrx. La posición es el número de página.
class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({super.key, required this.book, required this.bytes});

  final Book book;
  final Uint8List bytes;

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
    _initialPage = saved is PagePosition && saved.page > 0 ? saved.page : 1;
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
