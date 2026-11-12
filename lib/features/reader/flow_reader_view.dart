import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../data/models/book.dart';
import '../../data/models/highlight.dart';
import '../../data/repositories/highlights_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'document/reader_document.dart';
import 'reader_palette.dart';
import 'reader_providers.dart';
import 'reader_screen.dart';
import 'widgets/block_view.dart';
import 'widgets/highlight_sheets.dart';
import 'widgets/reader_chrome.dart';
import 'widgets/reader_sheets.dart';

/// Lector de EPUB y DOCX: lista continua de bloques.
class FlowReaderView extends ConsumerStatefulWidget {
  const FlowReaderView({
    super.key,
    required this.book,
    required this.document,
    this.initialBlock,
  });

  final Book book;
  final ReaderDocument document;

  /// Abrir en este bloque (p. ej. desde "Mis citas") en vez de la posición
  /// guardada.
  final int? initialBlock;

  @override
  ConsumerState<FlowReaderView> createState() => _FlowReaderViewState();
}

class _FlowReaderViewState extends ConsumerState<FlowReaderView>
    with ReaderStateMixin {
  final _scroll = ScrollController();
  final _list = ListController();
  Timer? _saveTimer;

  int _current = 0;
  bool _atEnd = false;

  /// Mientras se arrastra la barra de progreso.
  double? _seekPreview;

  List<DocBlock> get _blocks => widget.document.blocks;
  int get _lastIndex => _blocks.length - 1;

  @override
  String get bookId => widget.book.id;

  @override
  void initState() {
    super.initState();
    final saved = ReadingPosition.parse(widget.book.position);
    if (widget.initialBlock != null) {
      _current = widget.initialBlock!.clamp(0, _lastIndex);
    } else if (saved is BlockPosition) {
      _current = saved.index.clamp(0, _lastIndex);
    }
    _scroll.addListener(_onScroll);
    // El rango visible se actualiza tras el layout: se escucha aquí y no en
    // el scroll (que llega antes del layout, con el rango del frame anterior).
    _list.addListener(_onLayout);
    if (_current > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(_current));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  @override
  (String, double)? currentProgress() {
    final progress = _atEnd || _lastIndex <= 0 ? 1.0 : _current / _lastIndex;
    return (BlockPosition(_current).encode(), progress);
  }

  void _onScroll() {
    if (chromeVisible) setChromeVisible(false);
  }

  bool _updateScheduled = false;

  void _onLayout() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updatePosition();
    });
  }

  void _updatePosition() {
    final range = _list.isAttached ? _list.visibleRange : null;
    if (range == null || !_scroll.hasClients) return;
    final (first, last) = range;
    final atEnd =
        last >= _lastIndex &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 8;
    if (first != _current || atEnd != _atEnd) {
      readingActivity();
      setState(() {
        _current = first;
        _atEnd = atEnd;
      });
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 800), saveNow);
    }
    if (atEnd) onReachedEnd();
  }

  void _jumpTo(int index) {
    if (!_list.isAttached || !_scroll.hasClients) return;
    _list.jumpToItem(
      index: index.clamp(0, _lastIndex),
      scrollController: _scroll,
      alignment: 0,
    );
    // Deja el bloque debajo de la barra superior, no tapado por ella.
    final position = _scroll.position;
    final adjusted = (position.pixels - _chromeOffset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scroll.jumpTo(adjusted);
    setState(() => _current = index.clamp(0, _lastIndex));
    saveNow();
  }

  /// Alto de la barra superior + un margen.
  static const _chromeOffset = 72.0;

  int _indexFor(double fraction) => (fraction * _lastIndex).round();

  Future<void> _openToc(ReaderPalette palette) async {
    final toc = widget.document.toc;
    final current = widget.document.tocEntryFor(_current);
    final target = await showTocSheet(
      context,
      palette: palette,
      items: [
        for (final e in toc) TocItem(e.title, e.blockIndex, level: e.level),
      ],
      currentIndex: current == null ? null : toc.indexOf(current),
    );
    if (target != null) _jumpTo(target);
  }

  // ------------------------------------------------------------ Subrayados

  HighlightsRepository get _highlights =>
      ref.read(highlightsRepositoryProvider);

  String _blockText(int index) => switch (_blocks[index]) {
    ParagraphBlock(:final text) || HeadingBlock(:final text) => text,
    _ => '',
  };

  String _locationOf(Highlight h) {
    final chapter = h.blockIndex == null
        ? null
        : widget.document.tocEntryFor(h.blockIndex!)?.title;
    final percent = h.blockIndex == null || _lastIndex <= 0
        ? 0
        : (h.blockIndex! / _lastIndex * 100).round();
    return chapter == null ? '$percent %' : '$chapter · $percent %';
  }

  BlockActions _actionsFor(int index, ReaderPalette palette) => BlockActions(
    onTapText: toggleChrome,
    onHighlight: (start, end) => _highlights.addBlockHighlight(
      bookId: bookId,
      blockIndex: index,
      start: start,
      end: end,
      blockText: _blockText(index),
    ),
    onNote: (start, end) async {
      final text = _blockText(index);
      final result = await showHighlightEditor(
        context,
        palette: palette,
        quote: text.substring(start, end).trim(),
        location: _locationOf(
          Highlight(
            id: '',
            bookId: bookId,
            text: '',
            blockIndex: index,
            createdAt: DateTime.now(),
          ),
        ),
      );
      if (result is SaveHighlight) {
        await _highlights.addBlockHighlight(
          bookId: bookId,
          blockIndex: index,
          start: start,
          end: end,
          blockText: text,
          color: result.color,
          note: result.note,
        );
      }
    },
    onEdit: (h) => _edit(h, palette),
    onRemove: (list) async {
      for (final h in list) {
        await _highlights.delete(h.id);
      }
    },
  );

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
        await _highlights.update(
          h.copyWith(color: color, note: note, clearNote: note == null),
        );
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
    );
    if (target?.blockIndex != null) _jumpTo(target!.blockIndex!);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final byBlock = <int, List<Highlight>>{};
    for (final h in ref.watch(bookHighlightsProvider(bookId))) {
      if (h.blockIndex != null) (byBlock[h.blockIndex!] ??= []).add(h);
    }
    final palette = ReaderPalette.resolve(
      settings.readerTheme,
      Theme.of(context),
    );
    final style = ReaderTextStyle(
      palette: palette,
      fontSize: settings.readerFontSize,
      lineHeight: settings.readerLineHeight,
      justify: settings.readerJustify,
    );

    final shownIndex = _seekPreview != null
        ? _indexFor(_seekPreview!)
        : _current;
    final chapter = widget.document.tocEntryFor(shownIndex)?.title;
    final progress =
        _seekPreview ??
        (_atEnd || _lastIndex <= 0 ? 1.0 : _current / _lastIndex);
    final percent = (progress * 100).round();

    return ReaderChrome(
      visible: chromeVisible,
      palette: palette,
      title: widget.book.title,
      subtitle: chapter,
      progress: progress,
      progressLabel: chapter == null ? '$percent %' : '$chapter · $percent %',
      onSeekPreview: (v) => setState(() => _seekPreview = v),
      onSeek: (v) {
        setState(() => _seekPreview = null);
        _jumpTo(_indexFor(v));
      },
      onToc: widget.document.toc.isEmpty ? null : () => _openToc(palette),
      onNotes: () => _openNotes(palette),
      onSettings: () => showReaderSettings(context, palette: palette),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: toggleChrome,
        child: SafeArea(
          child: Scrollbar(
            controller: _scroll,
            child: SuperListView.builder(
              controller: _scroll,
              listController: _list,
              padding: const EdgeInsets.fromLTRB(0, 72, 0, 120),
              itemCount: _blocks.length,
              itemBuilder: (context, i) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: BlockView(
                      block: _blocks[i],
                      style: style,
                      highlights: byBlock[i] ?? const [],
                      actions: _actionsFor(i, palette),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
