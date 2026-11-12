import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littera/features/reader/document/reader_document.dart';
import 'package:littera/features/reader/reader_palette.dart';
import 'package:littera/features/reader/widgets/block_view.dart';

void main() {
  testWidgets('los párrafos se leen como texto y ofrecen subrayar o anotar', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final calls = <String>[];
    const style = ReaderTextStyle(
      palette: ReaderPalette.light,
      fontSize: 18,
      lineHeight: 1.6,
      justify: true,
    );
    final actions = BlockActions(
      onTapText: () {},
      onHighlight: (s, e) => calls.add('subrayar $s-$e'),
      onNote: (s, e) => calls.add('nota $s-$e'),
      onEdit: (_) {},
      onRemove: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BlockView(
                block: const HeadingBlock(1, [TextRun('Capítulo 1')]),
                style: style,
                actions: actions,
              ),
              BlockView(
                block: const ParagraphBlock([
                  TextRun('Hola '),
                  TextRun('mundo', bold: true),
                ]),
                style: style,
                actions: actions,
              ),
            ],
          ),
        ),
      ),
    );

    final heading = tester.getSemantics(find.bySemanticsLabel('Capítulo 1'));
    expect(heading.getSemanticsData().flagsCollection.isHeader, isTrue);

    final paragraph = tester.getSemantics(find.bySemanticsLabel('Hola mundo'));
    final data = paragraph.getSemanticsData();
    expect(data.flagsCollection.isTextField, isFalse);
    final ids = data.customSemanticsActionIds!;
    final labels = [
      for (final id in ids) CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, containsAll(['Subrayar párrafo', 'Añadir nota al párrafo']));

    final highlightId = ids.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == 'Subrayar párrafo',
    );
    paragraph.owner!.performAction(
      paragraph.id,
      SemanticsAction.customAction,
      highlightId,
    );
    expect(calls, ['subrayar 0-10']);
    handle.dispose();
  });
}
