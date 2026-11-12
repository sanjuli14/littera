import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';
import '../../app/theme/littera_theme.dart';

/// Tarjeta del diseño: fondo blanco (tinta clara en oscuro), esquinas
/// grandes y una sombra amplia y suave (no el contorno corto de Material).
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.radius = LitteraTheme.radiusCard,
    this.color,
  });

  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background =
        color ??
        (dark
            ? LitteraColors.nocheCarta
            : theme.colorScheme.surface == Colors.white
            ? Colors.white
            : theme.colorScheme.surfaceContainerLowest);
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.07),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: background,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
