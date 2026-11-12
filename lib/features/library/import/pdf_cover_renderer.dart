import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

/// Genera una carátula a partir de la primera página de un PDF.
abstract class PdfCoverRenderer {
  Future<Uint8List?> renderFirstPage(Uint8List pdfBytes);
}

class PdfrxCoverRenderer implements PdfCoverRenderer {
  static const _renderWidth = 900;

  @override
  Future<Uint8List?> renderFirstPage(Uint8List pdfBytes) async {
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(pdfBytes, sourceName: 'cover');
    try {
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      final scale = _renderWidth / page.width;
      final width = _renderWidth;
      final height = (page.height * scale).round();
      final rendered = await page.render(
        width: width,
        height: height,
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) return null;
      try {
        final image = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        );
        return img.encodeJpg(image, quality: 90);
      } finally {
        rendered.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }
}

final pdfCoverRendererProvider = Provider<PdfCoverRenderer>(
  (ref) => PdfrxCoverRenderer(),
);
