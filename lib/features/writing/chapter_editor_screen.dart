import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/manuscript.dart';
import '../../data/repositories/writing_repository.dart';
import 'entity_widgets.dart';
import 'word_count.dart';
import 'writing_screen.dart';

/// Retardo del guardado automático tras dejar de escribir.
const autosaveDelay = Duration(milliseconds: 1500);

enum _SaveStatus { saved, pending, saving }

/// Convierte el contenido guardado en un documento del editor.
Document documentFromContent(String content) {
  if (content.trim().isEmpty) return Document();
  try {
    final data = jsonDecode(content);
    if (data is List && data.isNotEmpty) return Document.fromJson(data);
  } catch (_) {
    // Contenido antiguo o dañado: se trata como texto plano.
    return Document()..insert(0, content);
  }
  return Document();
}

String contentFromDocument(Document doc) => jsonEncode(doc.toDelta().toJson());

/// Editor de un capítulo, a pantalla completa.
class ChapterEditorScreen extends ConsumerStatefulWidget {
  const ChapterEditorScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  ConsumerState<ChapterEditorScreen> createState() =>
      _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends ConsumerState<ChapterEditorScreen> {
  late final WritingRepository _repo;
  late final AppLifecycleListener _lifecycle;
  final _focusNode = FocusNode();
  final _scroll = ScrollController();

  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  Timer? _saveTimer;

  Chapter? _chapter;

  /// Contenido al abrir: se guarda como versión en el primer guardado,
  /// para poder volver al texto anterior a esta sesión.
  late String _sessionStart;
  bool _sessionSnapshotDone = false;

  _SaveStatus _status = _SaveStatus.saved;

  /// `true` desde que empieza dispose: ya no se puede llamar a setState.
  bool _closing = false;
  int _words = 0;
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(writingRepositoryProvider);
    _chapter = _repo.chapters.get(widget.chapterId);
    _sessionStart = _chapter?.content ?? '';
    if (_chapter != null) _attach(documentFromContent(_sessionStart));
    _focusNode.addListener(_onFocusChanged);
    _lifecycle = AppLifecycleListener(
      onHide: _saveNow,
      onPause: _saveNow,
      onDetach: _saveNow,
    );
  }

  void _attach(Document doc) {
    _changes?.cancel();
    if (_controller == null) {
      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _controller!.document = doc;
    }
    _words = countWords(doc.toPlainText());
    _changes = doc.changes.listen((_) => _onChanged());
  }

  void _onFocusChanged() {
    if (mounted) setState(() {}); // refleja el foco en la semántica
  }

  @override
  void dispose() {
    _closing = true;
    _lifecycle.dispose();
    _saveTimer?.cancel();
    _changes?.cancel();
    _saveNow();
    _controller?.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    if (_focusMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _onChanged() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _status = _SaveStatus.pending;
      _words = countWords(c.document.toPlainText());
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, _saveNow);
  }

  /// Guarda si hay cambios. Seguro de llamar varias veces.
  Future<void> _saveNow() async {
    final c = _controller;
    if (c == null || _status == _SaveStatus.saved) return;
    _saveTimer?.cancel();
    final content = contentFromDocument(c.document);
    _setStatus(_SaveStatus.saving);
    if (!_sessionSnapshotDone) {
      _sessionSnapshotDone = true;
      await _repo.snapshot(
        widget.chapterId,
        content: _sessionStart,
        label: 'Al abrir',
      );
    }
    await _repo.saveChapterContent(widget.chapterId, content);
    _setStatus(_SaveStatus.saved);
  }

  void _setStatus(_SaveStatus status) {
    if (_closing || !mounted) {
      _status = status;
      return;
    }
    setState(() => _status = status);
  }

  void _toggleFocus() {
    setState(() => _focusMode = !_focusMode);
    SystemChrome.setEnabledSystemUIMode(
      _focusMode ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _rename() async {
    final chapter = _repo.chapters.get(widget.chapterId);
    if (chapter == null) return;
    final title = await showTextInputDialog(
      context,
      title: 'Título del capítulo',
      initialValue: chapter.title,
      label: 'Título',
    );
    if (title == null) return;
    await _repo.renameChapter(chapter, title);
    if (mounted) setState(() => _chapter = _repo.chapters.get(chapter.id));
  }

  Future<void> _openEntities() {
    final manuscriptId = _chapter!.manuscriptId;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fichas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showEntityEditor(
                      context,
                      ref,
                      manuscriptId: manuscriptId,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EntityList(
                manuscriptId: manuscriptId,
                scrollController: controller,
                bottomPadding: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVersions() async {
    await _saveNow();
    if (!mounted) return;
    final restored = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VersionsSheet(chapterId: widget.chapterId),
    );
    if (restored == true && mounted) {
      final content = _repo.chapters.get(widget.chapterId)?.content ?? '';
      setState(() {
        _attach(documentFromContent(content));
        _status = _SaveStatus.saved;
      });
      showMessage(context, 'Versión restaurada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    final controller = _controller;
    if (chapter == null || controller == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este capítulo ya no existe')),
      );
    }
    final theme = Theme.of(context);

    final statusText = switch (_status) {
      _SaveStatus.saved => 'Guardado',
      _SaveStatus.pending => 'Sin guardar',
      _SaveStatus.saving => 'Guardando…',
    };

    return Scaffold(
      appBar: _focusMode
          ? null
          : AppBar(
              titleSpacing: 0,
              title: InkWell(
                onTap: _rename,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _status == _SaveStatus.saved
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  tooltip: 'Fichas',
                  onPressed: _openEntities,
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Versiones',
                  onPressed: _openVersions,
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Modo sin distracciones',
                  onPressed: _toggleFocus,
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_focusMode)
              Material(
                color: theme.colorScheme.surfaceContainer,
                child: QuillSimpleToolbar(
                  controller: controller,
                  config: const QuillSimpleToolbarConfig(
                    multiRowsDisplay: false,
                    showDividers: true,
                    showFontFamily: false,
                    showFontSize: false,
                    showBoldButton: true,
                    showItalicButton: true,
                    showSmallButton: false,
                    showUnderLineButton: false,
                    showLineHeightButton: false,
                    showStrikeThrough: false,
                    showInlineCode: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: true,
                    showAlignmentButtons: false,
                    showHeaderStyle: true,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: false,
                    showCodeBlock: false,
                    showQuote: true,
                    showIndent: false,
                    showLink: false,
                    showUndo: true,
                    showRedo: true,
                    showDirection: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  // Quill no se declara como campo de texto: con lector de
                  // pantalla (y en Web con accesibilidad activa, donde el
                  // navegador solo crea el campo de entrada para un campo de
                  // texto semántico enfocado) no se podría escribir.
                  Semantics(
                    container: true,
                    textField: true,
                    multiline: true,
                    focused: _focusNode.hasFocus,
                    label: 'Texto del capítulo',
                    onTap: _focusNode.requestFocus,
                    onFocus: _focusNode.requestFocus,
                    child: QuillEditor(
                      controller: controller,
                      focusNode: _focusNode,
                      scrollController: _scroll,
                      config: QuillEditorConfig(
                        placeholder: 'Empieza a escribir…',
                        padding: EdgeInsets.fromLTRB(
                          24,
                          _focusMode ? 32 : 16,
                          24,
                          120,
                        ),
                        maxContentWidth: 720,
                        expands: true,
                        autoFocus: chapter.content.isEmpty,
                      ),
                    ),
                  ),
                  if (_focusMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit),
                        tooltip: 'Salir del modo sin distracciones',
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: _toggleFocus,
                      ),
                    ),
                ],
              ),
            ),
            if (!_focusMode)
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatWordCount(_words),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de versiones: ver, restaurar, guardar una ahora o borrar.
class _VersionsSheet extends ConsumerWidget {
  const _VersionsSheet({required this.chapterId});

  final String chapterId;

  String _time(DateTime d) =>
      '${formatDate(d)}, ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final versions = ref.watch(versionsOfProvider(chapterId));
    final repo = ref.read(writingRepositoryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Versiones', style: theme.textTheme.titleLarge),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final label = await showTextInputDialog(
                      context,
                      title: 'Guardar versión',
                      label: 'Nombre (opcional)',
                      confirmLabel: 'Guardar',
                    );
                    if (label == null) return;
                    final saved = await repo.snapshot(
                      chapterId,
                      manual: true,
                      label: label.isEmpty ? null : label,
                    );
                    if (saved == null && context.mounted) {
                      showMessage(context, 'El capítulo está vacío');
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Guardar ahora'),
                ),
              ],
            ),
          ),
          Expanded(
            child: versions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Littera guarda una versión cada vez que abres el '
                        'capítulo y empiezas a escribir. También puedes '
                        'guardar una cuando quieras.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: versions.length,
                    itemBuilder: (context, i) {
                      final v = versions[i];
                      return ListTile(
                        leading: Icon(
                          v.manual ? Icons.bookmark : Icons.history,
                          color: v.manual ? LitteraColors.oro : null,
                        ),
                        title: Text(v.label ?? _time(v.createdAt)),
                        subtitle: Text(
                          '${v.label == null ? '' : '${_time(v.createdAt)} · '}'
                          '${formatWordCount(v.wordCount)}',
                        ),
                        onTap: () async {
                          final restore = await showDialog<bool>(
                            context: context,
                            builder: (_) => _VersionPreview(version: v),
                          );
                          if (restore == true) {
                            await repo.restoreVersion(v);
                            if (context.mounted) Navigator.pop(context, true);
                          }
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Borrar versión',
                          onPressed: () => repo.deleteVersion(v.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _VersionPreview extends StatelessWidget {
  const _VersionPreview({required this.version});
  final ChapterVersion version;

  @override
  Widget build(BuildContext context) {
    final text = plainTextFromDelta(version.content).trim();
    return AlertDialog(
      title: Text(version.label ?? formatDate(version.createdAt)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Text(text.isEmpty ? '(vacío)' : text),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restaurar esta versión'),
        ),
      ],
    );
  }
}
