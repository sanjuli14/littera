import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../app/theme/littera_colors.dart';

/// Dibuja una carátula con la paleta de Littera (tinta, marco oro, título en
/// pergamino) y la devuelve en PNG de 600×900.
Future<Uint8List> renderGeneratedCover(String title, String author) async {
  const w = 600.0, h = 900.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = LitteraColors.tinta,
  );
  canvas.drawRect(
    const Rect.fromLTWH(36, 36, w - 72, h - 72),
    Paint()
      ..color = LitteraColors.oro
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  TextPainter painter(String text, TextStyle style, int maxLines) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: w - 150);

  final titlePainter = painter(
    title.isEmpty ? 'Sin título' : title,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 54,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: LitteraColors.pergamino,
    ),
    6,
  );
  final authorPainter = author.isEmpty
      ? null
      : painter(
          author,
          const TextStyle(
            fontFamily: 'Inter',
            fontSize: 30,
            color: LitteraColors.oro,
          ),
          2,
        );

  const gap = 40.0;
  final blockHeight =
      titlePainter.height +
      (authorPainter == null ? 0 : gap * 2 + authorPainter.height);
  var y = (h - blockHeight) / 2 - 20;

  titlePainter.paint(canvas, Offset((w - titlePainter.width) / 2, y));
  y += titlePainter.height + gap;
  if (authorPainter != null) {
    canvas.drawLine(
      Offset(w / 2 - 50, y),
      Offset(w / 2 + 50, y),
      Paint()
        ..color = LitteraColors.oro
        ..strokeWidth = 3,
    );
    y += gap;
    authorPainter.paint(canvas, Offset((w - authorPainter.width) / 2, y));
  }

  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
