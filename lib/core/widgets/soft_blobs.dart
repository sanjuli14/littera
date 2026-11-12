import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';

/// Manchas orgánicas suaves (pergamino y oro) para fondos decorativos.
/// Dan calidez sin competir con el contenido.
class SoftBlobs extends StatelessWidget {
  const SoftBlobs({super.key, this.child, this.variant = 0});

  final Widget? child;

  /// Cambia la disposición para que no todas las pantallas se vean iguales.
  final int variant;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _BlobPainter(dark: dark, variant: variant),
      child: child,
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.dark, required this.variant});

  final bool dark;
  final int variant;

  Path _blob(Offset c, double r, double wobble) {
    // Seis puntos alrededor de un círculo, unidos con curvas suaves.
    const n = 6;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        c +
            Offset.fromDirection(
              i * 2 * 3.14159265 / n,
              r * (1 + (i.isEven ? wobble : -wobble)),
            ),
    ];
    final path = Path()
      ..moveTo((pts[0].dx + pts[1].dx) / 2, (pts[0].dy + pts[1].dy) / 2);
    for (var i = 1; i <= n; i++) {
      final p = pts[i % n];
      final next = pts[(i + 1) % n];
      path.quadraticBezierTo(
        p.dx,
        p.dy,
        (p.dx + next.dx) / 2,
        (p.dy + next.dy) / 2,
      );
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final warm = dark
        ? LitteraColors.tintaClara
        : LitteraColors.pergamino.withValues(alpha: 0.75);
    final gold = LitteraColors.oro.withValues(alpha: dark ? 0.16 : 0.22);
    final w = size.width, h = size.height;

    if (variant == 0) {
      canvas.drawPath(
        _blob(Offset(w * 0.92, h * 0.12), w * 0.42, 0.12),
        Paint()..color = warm,
      );
      canvas.drawPath(
        _blob(Offset(w * 0.08, h * 0.02), w * 0.18, 0.18),
        Paint()..color = gold,
      );
    } else {
      canvas.drawPath(
        _blob(Offset(w * 0.5, h * 0.42), w * 0.36, 0.1),
        Paint()..color = warm,
      );
      canvas.drawPath(
        _blob(Offset(w * 0.82, h * 0.18), w * 0.09, 0.2),
        Paint()..color = gold,
      );
      canvas.drawPath(
        _blob(Offset(w * 0.18, h * 0.72), w * 0.06, 0.25),
        Paint()..color = gold,
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.dark != dark || old.variant != variant;
}
