import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';
import '../../data/models/app_settings.dart';

/// Colores de la página de lectura.
class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.text,
    required this.secondary,
    required this.chrome,
    required this.brightness,
  });

  final Color background;
  final Color text;
  final Color secondary;

  /// Fondo de las barras superior e inferior.
  final Color chrome;
  final Brightness brightness;

  static const light = ReaderPalette(
    background: LitteraColors.pergaminoClaro,
    text: Color(0xFF232B45),
    secondary: Color(0xFF6B6F82),
    chrome: Color(0xFFF5EEDD),
    brightness: Brightness.light,
  );

  static const sepia = ReaderPalette(
    background: LitteraColors.pergamino,
    text: Color(0xFF3A3226),
    secondary: Color(0xFF7A6E58),
    chrome: LitteraColors.pergaminoMedio,
    brightness: Brightness.light,
  );

  static const dark = ReaderPalette(
    background: LitteraColors.tinta,
    text: Color(0xFFE6DCC4),
    secondary: Color(0xFFA9A390),
    chrome: LitteraColors.tintaClara,
    brightness: Brightness.dark,
  );

  /// Paleta según el ajuste del lector y el tema actual de la app.
  static ReaderPalette resolve(ReaderTheme theme, ThemeData appTheme) =>
      switch (theme) {
        ReaderTheme.light => light,
        ReaderTheme.sepia => sepia,
        ReaderTheme.dark => dark,
        ReaderTheme.auto =>
          appTheme.brightness == Brightness.dark
              ? dark
              : appTheme.colorScheme.surface == LitteraColors.pergamino
              ? sepia
              : light,
      };

  static ReaderPalette forTheme(ReaderTheme theme) => switch (theme) {
    ReaderTheme.sepia => sepia,
    ReaderTheme.dark => dark,
    _ => light,
  };
}
