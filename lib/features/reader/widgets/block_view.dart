import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../app/theme/littera_theme.dart';
import '../../../data/models/highlight.dart';
import '../document/reader_document.dart';
import '../reader_palette.dart';

/// Estilo de texto del lector, calculado una vez por build.
class ReaderTextStyle {
  const ReaderTextStyle({
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
    required this.justify,
    this.serif = true,
  });

  final bool serif;
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;
  final bool justify;

  TextStyle get body => TextStyle(
    color: palette.text,
    fontSize: fontSize,
    height: lineHeight,
    fontFamily: serif ? LitteraTheme.serif : LitteraTheme.fontFamily,
  );
}

/// Acciones sobre el texto de un bloque.
class BlockActions {
  const BlockActions({
    required this.onTapText,
    required this.onHighlight,
    required this.onNote,
    required this.onEdit,
    required this.onRemove,
  });

  /// Toque simple sobre el texto (mostrar/ocultar barras).
  final VoidCallback onTapText;
  final void Function(int start, int end) onHighlight;
  final void Function(int start, int end) onNote;
  final void Function(Highlight highlight) onEdit;
  final void Function(List<Highlight> highlights) onRemove;
}

/// Divide los fragmentos de texto según los subrayados y aplica su color.
List<InlineSpan> highlightedSpans(
  List<TextRun> runs,
  List<Highlight> highlights,
) {
  if (highlights.isEmpty) {
    return [for (final r in runs) TextSpan(text: r.text, style: _runStyle(r))];
  }

  // Bordes: inicio/fin de cada fragmento y de cada subrayado.
  final cuts = <int>{0};
  var offset = 0;
  final runStarts = <int>[];
  for (final r in runs) {
    runStarts.add(offset);
    offset += r.text.length;
    cuts.add(offset);
  }
  final total = offset;
  for (final h in highlights) {
    cuts
      ..add((h.start ?? 0).clamp(0, total))
      ..add((h.end ?? 0).clamp(0, total));
  }
  final sorted = cuts.toList()..sort();

  final spans = <InlineSpan>[];
  var runIndex = 0;
  for (var i = 0; i < sorted.length - 1; i++) {
    final a = sorted[i], b = sorted[i + 1];
    if (a == b) continue;
    while (runIndex < runs.length - 1 && runStarts[runIndex + 1] <= a) {
      runIndex++;
    }
    final run = runs[runIndex];
    final text = run.text.substring(
      a - runStarts[runIndex],
      b - runStarts[runIndex],
    );
    // El más reciente gana si se solapan.
    Highlight? cover;
    for (final h in highlights) {
      if ((h.start ?? 0) <= a && (h.end ?? 0) >= b) {
        if (cover == null || h.createdAt.isAfter(cover.createdAt)) cover = h;
      }
    }
    var style = _runStyle(run);
    if (cover != null) {
      style = style.copyWith(
        backgroundColor: cover.color.color.withValues(alpha: 0.38),
        decoration: cover.hasNote ? TextDecoration.underline : null,
        decorationColor: cover.color.color,
        decorationStyle: TextDecorationStyle.dotted,
        decorationThickness: 2,
      );
    }
    spans.add(TextSpan(text: text, style: style));
  }
  return spans;
}

TextStyle _runStyle(TextRun r) => TextStyle(
  fontWeight: r.bold ? FontWeight.w700 : null,
  fontStyle: r.italic ? FontStyle.italic : null,
);

/// Dibuja un bloque del documento.
class BlockView extends StatelessWidget {
  const BlockView({
    super.key,
    required this.block,
    required this.style,
    this.highlights = const [],
    this.actions,
  });

  final DocBlock block;
  final ReaderTextStyle style;

  /// Subrayados de este bloque.
  final List<Highlight> highlights;

  /// `null` = texto no seleccionable (p. ej. vistas previas).
  final BlockActions? actions;

  @override
  Widget build(BuildContext context) {
    final fs = style.fontSize;
    final body = style.body;

    return switch (block) {
      HeadingBlock(:final level, :final runs) => Padding(
        padding: EdgeInsets.only(
          top: fs * (level <= 2 ? 1.8 : 1.2),
          bottom: fs * 0.8,
        ),
        child: _text(
          context,
          runs,
          header: true,
          textAlign: level <= 2 ? TextAlign.center : TextAlign.start,
          textStyle: body.copyWith(
            fontSize:
                fs *
                switch (level) {
                  1 => 1.6,
                  2 => 1.35,
                  3 => 1.2,
                  _ => 1.05,
                },
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ParagraphBlock(:final runs, :final kind) => _paragraph(
        context,
        runs,
        kind,
        body,
      ),
      ImageBlock(:final bytes, :final alt) => Padding(
        padding: EdgeInsets.symmetric(vertical: fs * 0.8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              semanticLabel: alt,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      SeparatorBlock() => Padding(
        padding: EdgeInsets.symmetric(vertical: fs),
        child: Center(
          child: Text(
            '✦   ✦   ✦',
            style: TextStyle(color: LitteraColors.oro, fontSize: fs * 0.7),
          ),
        ),
      ),
    };
  }

  /// Texto (seleccionable si hay [actions]) con los subrayados pintados.
  Widget _text(
    BuildContext context,
    List<TextRun> runs, {
    required TextAlign textAlign,
    required TextStyle textStyle,
    bool header = false,
  }) {
    final span = TextSpan(children: highlightedSpans(runs, highlights));
    final a = actions;
    if (a == null) {
      return Semantics(
        header: header,
        child: Text.rich(span, textAlign: textAlign, style: textStyle),
      );
    }
    final plain = runs.map((r) => r.text).join();

    final withNotes = highlights.where((h) => h.hasNote).toList();
    final text = SelectableText.rich(
      span,
      textAlign: textAlign,
      style: textStyle,
      onTap: a.onTapText,
      contextMenuBuilder: (context, state) {
        final selection = state.textEditingValue.selection;
        if (!selection.isValid || selection.isCollapsed) {
          return AdaptiveTextSelectionToolbar.editableText(
            editableTextState: state,
          );
        }
        final start = selection.start, end = selection.end;
        final overlapping = highlights
            .where((h) => (h.start ?? 0) < end && (h.end ?? 0) > start)
            .toList();

        void run(VoidCallback action) {
          state.hideToolbar();
          state.userUpdateTextEditingValue(
            state.textEditingValue.copyWith(
              selection: TextSelection.collapsed(offset: end),
            ),
            SelectionChangedCause.toolbar,
          );
          action();
        }

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ContextMenuButtonItem(
              label: 'Subrayar',
              onPressed: () => run(() => a.onHighlight(start, end)),
            ),
            ContextMenuButtonItem(
              label: 'Nota',
              onPressed: () => run(() => a.onNote(start, end)),
            ),
            if (overlapping.isNotEmpty) ...[
              ContextMenuButtonItem(
                label: 'Editar',
                onPressed: () => run(() => a.onEdit(overlapping.first)),
              ),
              ContextMenuButtonItem(
                label: 'Quitar',
                onPressed: () => run(() => a.onRemove(overlapping)),
              ),
            ],
            ContextMenuButtonItem(
              type: ContextMenuButtonType.copy,
              onPressed: () {
                state.copySelection(SelectionChangedCause.toolbar);
              },
            ),
          ],
        );
      },
    );

    // Para lectores de pantalla: el párrafo se anuncia como texto (no como
    // campo de edición, que es lo que expone SelectableText) y, como no se
    // puede seleccionar con gestos, ofrece subrayar o anotar el párrafo entero.
    final accessible = Semantics(
      label: plain,
      header: header,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Subrayar párrafo'): () =>
            a.onHighlight(0, plain.length),
        const CustomSemanticsAction(label: 'Añadir nota al párrafo'): () =>
            a.onNote(0, plain.length),
        if (withNotes.isNotEmpty)
          const CustomSemanticsAction(label: 'Ver nota'): () =>
              a.onEdit(withNotes.first),
      },
      child: ExcludeSemantics(child: text),
    );

    if (withNotes.isEmpty) return accessible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        accessible,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: LitteraColors.oro,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => a.onEdit(withNotes.first),
            icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
            label: Text(
              withNotes.length == 1 ? 'Nota' : '${withNotes.length} notas',
            ),
          ),
        ),
      ],
    );
  }

  Widget _paragraph(
    BuildContext context,
    List<TextRun> runs,
    ParagraphKind kind,
    TextStyle body,
  ) {
    final fs = style.fontSize;
    final text = _text(
      context,
      runs,
      textAlign: switch (kind) {
        ParagraphKind.center => TextAlign.center,
        ParagraphKind.preformatted || ParagraphKind.listItem => TextAlign.start,
        _ => style.justify ? TextAlign.justify : TextAlign.start,
      },
      textStyle: switch (kind) {
        ParagraphKind.preformatted => body.copyWith(
          fontFamily: 'monospace',
          fontSize: fs * 0.85,
        ),
        ParagraphKind.quote => body.copyWith(fontStyle: FontStyle.italic),
        _ => body,
      },
    );

    final spacing = EdgeInsets.only(bottom: fs * 0.7);
    return switch (kind) {
      ParagraphKind.listItem => Padding(
        padding: spacing,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: fs * 1.4,
              child: Text('•', style: body.copyWith(color: LitteraColors.oro)),
            ),
            Expanded(child: text),
          ],
        ),
      ),
      ParagraphKind.quote => Container(
        margin: spacing,
        padding: EdgeInsets.only(left: fs),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: LitteraColors.oro, width: 3)),
        ),
        child: text,
      ),
      _ => Padding(padding: spacing, child: text),
    };
  }
}
