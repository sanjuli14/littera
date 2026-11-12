import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Ancho y alto de las carátulas guardadas (proporción 2:3).
const coverWidth = 600;
const coverHeight = 900;

/// Recorta al centro a proporción 2:3, redimensiona y codifica en JPEG.
/// Devuelve `null` si los bytes no son una imagen válida.
Future<Uint8List?> processCover(Uint8List bytes) =>
    compute(_processCoverSync, bytes);

Uint8List? _processCoverSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Aplana la transparencia sobre blanco (JPEG no tiene canal alfa).
  var source = decoded;
  if (decoded.hasAlpha) {
    source = img.Image(width: decoded.width, height: decoded.height)
      ..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(source, decoded);
  }

  const target = coverWidth / coverHeight;
  final ratio = source.width / source.height;
  var cropW = source.width;
  var cropH = source.height;
  if (ratio > target) {
    cropW = (source.height * target).round();
  } else if (ratio < target) {
    cropH = (source.width / target).round();
  }
  final cropped = img.copyCrop(
    source,
    x: (source.width - cropW) ~/ 2,
    y: (source.height - cropH) ~/ 2,
    width: cropW,
    height: cropH,
  );
  final resized = img.copyResize(
    cropped,
    width: coverWidth,
    height: coverHeight,
    interpolation: img.Interpolation.cubic,
  );
  return img.encodeJpg(resized, quality: 85);
}
