import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';

/// Estrellas de valoración (oro). Con [onChanged] se pueden tocar.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 14,
    this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outlineVariant;
    final label = rating == 0
        ? 'Sin valorar'
        : '$rating ${rating == 1 ? 'estrella' : 'estrellas'} de 5';

    if (onChanged == null) {
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= rating ? LitteraColors.oro : empty,
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Valoración: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
              visualDensity: VisualDensity.compact,
              iconSize: size,
              onPressed: () => onChanged!(i),
              icon: Icon(
                i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i <= rating ? LitteraColors.oro : empty,
              ),
            ),
        ],
      ),
    );
  }
}
