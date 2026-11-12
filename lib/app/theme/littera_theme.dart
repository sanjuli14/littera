import 'package:flutter/material.dart';

import 'littera_colors.dart';

/// Temas de Littera: claro, sepia y oscuro.
abstract final class LitteraTheme {
  static const fontFamily = 'Inter';

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get sepia => _build(_sepiaScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: LitteraColors.tinta,
    onPrimary: LitteraColors.pergamino,
    primaryContainer: LitteraColors.pergaminoMedio,
    onPrimaryContainer: LitteraColors.tinta,
    secondary: LitteraColors.oroOscuro,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFEBD9AF),
    onSecondaryContainer: LitteraColors.tinta,
    tertiary: LitteraColors.oro,
    onTertiary: LitteraColors.tinta,
    error: LitteraColors.error,
    onError: Colors.white,
    surface: LitteraColors.pergaminoClaro,
    onSurface: LitteraColors.tinta,
    onSurfaceVariant: Color(0xFF4A5170),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF8F3E7),
    surfaceContainer: Color(0xFFF5EEDD),
    surfaceContainerHigh: LitteraColors.pergamino,
    surfaceContainerHighest: LitteraColors.pergaminoMedio,
    outline: Color(0xFF8C8FA3),
    outlineVariant: LitteraColors.pergaminoOscuro,
  );

  static const _sepiaScheme = ColorScheme(
    brightness: Brightness.light,
    primary: LitteraColors.tinta,
    onPrimary: LitteraColors.pergamino,
    primaryContainer: LitteraColors.pergaminoOscuro,
    onPrimaryContainer: LitteraColors.tinta,
    secondary: LitteraColors.oroOscuro,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE2CC98),
    onSecondaryContainer: LitteraColors.tinta,
    tertiary: LitteraColors.oro,
    onTertiary: LitteraColors.tinta,
    error: LitteraColors.error,
    onError: Colors.white,
    surface: LitteraColors.pergamino,
    onSurface: LitteraColors.tinta,
    onSurfaceVariant: Color(0xFF4A5170),
    surfaceContainerLowest: LitteraColors.pergaminoClaro,
    surfaceContainerLow: Color(0xFFEEE3CB),
    surfaceContainer: LitteraColors.pergaminoMedio,
    surfaceContainerHigh: Color(0xFFE4D8BA),
    surfaceContainerHighest: LitteraColors.pergaminoOscuro,
    outline: Color(0xFF8C8670),
    outlineVariant: Color(0xFFD2C29C),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: LitteraColors.oro,
    onPrimary: LitteraColors.tinta,
    primaryContainer: Color(0xFF4A3D20),
    onPrimaryContainer: LitteraColors.pergamino,
    secondary: LitteraColors.pergamino,
    onSecondary: LitteraColors.tinta,
    secondaryContainer: Color(0xFF4A3F27),
    onSecondaryContainer: LitteraColors.pergamino,
    tertiary: LitteraColors.oro,
    onTertiary: LitteraColors.tinta,
    error: LitteraColors.errorClaro,
    onError: Color(0xFF601410),
    surface: LitteraColors.tinta,
    onSurface: LitteraColors.pergamino,
    onSurfaceVariant: Color(0xFFC5C0B0),
    surfaceContainerLowest: Color(0xFF151C31),
    surfaceContainerLow: Color(0xFF202A48),
    surfaceContainer: LitteraColors.tintaClara,
    surfaceContainerHigh: LitteraColors.tintaMedia,
    surfaceContainerHighest: LitteraColors.tintaAlta,
    outline: Color(0xFF8A8FA6),
    outlineVariant: Color(0xFF3B4870),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        // Tamaños explícitos: en este punto base.textTheme aún no los trae.
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: LitteraColors.oro.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LitteraColors.oro,
          foregroundColor: LitteraColors.tinta,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LitteraColors.oro,
        foregroundColor: LitteraColors.tinta,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LitteraColors.oro,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: LitteraColors.oro,
        selectionColor: LitteraColors.oro.withValues(alpha: 0.4),
        selectionHandleColor: LitteraColors.oro,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
