import 'package:flutter/material.dart';

import '../../../app/theme/littera_colors.dart';
import '../document/reader_document.dart';
import '../reader_palette.dart';

/// Estilo de texto del lector, calculado una vez por build.
class ReaderTextStyle {
  const ReaderTextStyle({
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
    required this.justify,
  });

  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;
  final bool justify;

  TextStyle get body =>
      TextStyle(color: palette.text, fontSize: fontSize, height: lineHeight);
}

/// Dibuja un bloque del documento.
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.block, required this.style});

  final DocBlock block;
  final ReaderTextStyle style;

  static List<InlineSpan> spans(List<TextRun> runs) => [
    for (final r in runs)
      TextSpan(
        text: r.text,
        style: TextStyle(
          fontWeight: r.bold ? FontWeight.w700 : null,
          fontStyle: r.italic ? FontStyle.italic : null,
        ),
      ),
  ];

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
        child: Text.rich(
          TextSpan(children: spans(runs)),
          textAlign: level <= 2 ? TextAlign.center : TextAlign.start,
          style: body.copyWith(
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
      ParagraphBlock(:final runs, :final kind) => _paragraph(runs, kind, body),
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

  Widget _paragraph(List<TextRun> runs, ParagraphKind kind, TextStyle body) {
    final fs = style.fontSize;
    final text = Text.rich(
      TextSpan(children: spans(runs)),
      textAlign: switch (kind) {
        ParagraphKind.center => TextAlign.center,
        ParagraphKind.preformatted || ParagraphKind.listItem => TextAlign.start,
        _ => style.justify ? TextAlign.justify : TextAlign.start,
      },
      style: kind == ParagraphKind.preformatted
          ? body.copyWith(fontFamily: 'monospace', fontSize: fs * 0.85)
          : body,
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
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontStyle: FontStyle.italic),
          child: text,
        ),
      ),
      _ => Padding(padding: spacing, child: text),
    };
  }
}
