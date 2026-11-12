import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'flow_reader_view.dart';
import 'pdf_reader_view.dart';
import 'reader_palette.dart';
import 'reader_providers.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// Copia del libro al abrirlo: la posición inicial no debe cambiar
  /// mientras se lee (el progreso se va guardando en segundo plano).
  Book? _openedBook;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(libraryRepositoryProvider);
    final book = repo.getBook(widget.bookId);
    if (book != null) {
      _openedBook = book;
      repo.markOpened(book);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = _openedBook;
    final palette = ReaderPalette.resolve(
      ref.watch(settingsProvider.select((s) => s.readerTheme)),
      Theme.of(context),
    );

    Widget body;
    if (book == null) {
      body = _Message(
        palette: palette,
        text: 'Este libro ya no está en tu biblioteca',
      );
    } else if (book.format == BookFormat.pdf) {
      body = ref
          .watch(bookBytesProvider(book.id))
          .when(
            loading: () => _Loading(palette: palette),
            error: (e, _) => _Message(palette: palette, text: '$e'),
            data: (bytes) => PdfReaderView(book: book, bytes: bytes),
          );
    } else {
      body = ref
          .watch(readerDocumentProvider(book.id))
          .when(
            loading: () => _Loading(palette: palette),
            error: (e, _) => _Message(
              palette: palette,
              text: 'No se pudo abrir el libro. El archivo puede estar dañado.',
            ),
            data: (doc) => doc.isEmpty
                ? _Message(palette: palette, text: 'Este libro no tiene texto')
                : FlowReaderView(book: book, document: doc),
          );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(backgroundColor: palette.background, body: body),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.palette});
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Abriendo libro…', style: TextStyle(color: palette.secondary)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.palette, required this.text});
  final ReaderPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: palette.text,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.text, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Mixin con lo común a ambos lectores: barras visibles, modo inmersivo,
/// guardado con retardo y aviso de libro terminado.
mixin ReaderStateMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Se lee en initState: en dispose ya no se puede usar `ref`.
  late final LibraryRepository repo;
  bool chromeVisible = true;
  bool _finishPrompted = false;
  late final AppLifecycleListener _lifecycle;

  String get bookId;

  /// Posición y progreso actuales, para guardar.
  (String position, double progress)? currentProgress();

  @override
  void initState() {
    super.initState();
    repo = ref.read(libraryRepositoryProvider);
    _lifecycle = AppLifecycleListener(
      onHide: saveNow,
      onPause: saveNow,
      onDetach: saveNow,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    saveNow();
    super.dispose();
  }

  void setChromeVisible(bool visible) {
    if (visible == chromeVisible) return;
    setState(() => chromeVisible = visible);
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void toggleChrome() => setChromeVisible(!chromeVisible);

  String? _lastSaved;

  void saveNow() {
    final current = currentProgress();
    if (current == null) return;
    final (position, progress) = current;
    final key = '$position|${progress.toStringAsFixed(4)}';
    if (key == _lastSaved) return;
    _lastSaved = key;
    repo.saveProgress(bookId, position, progress);
  }

  /// Al llegar al final, ofrece marcar el libro como terminado (una vez).
  void onReachedEnd() {
    if (_finishPrompted) return;
    final book = repo.getBook(bookId);
    if (book == null || book.status == ReadingStatus.finished) return;
    _finishPrompted = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¿Terminaste el libro?'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Marcar terminado',
          onPressed: () => repo.markFinished(bookId),
        ),
      ),
    );
  }
}
