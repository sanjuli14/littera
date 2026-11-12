import 'package:flutter/material.dart';

import 'littera_colors.dart';

/// Temas de Littera: claro (blanco), sepia y oscuro.
///
/// Lenguaje visual: fondos limpios, tarjetas con sombra suave y esquinas
/// grandes, botones y pestañas en forma de píldora, títulos en negrita.
/// Tinta = lo activo (botones, pestaña e icono seleccionados);
/// oro = progreso, estrellas y detalles.
abstract final class LitteraTheme {
  /// Interfaz (la de la referencia: geométrica y redonda).
  static const fontFamily = 'Montserrat';

  /// Lectura, citas y momentos literarios.
  static const serif = 'Lora';

  /// Radios del diseño.
  static const radiusCard = 22.0;
  static const radiusHero = 28.0;

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get sepia => _build(_sepiaScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: LitteraColors.tinta,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE8EAF2),
    onPrimaryContainer: LitteraColors.tinta,
    secondary: LitteraColors.oroOscuro,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF5ECD8),
    onSecondaryContainer: LitteraColors.tinta,
    tertiary: LitteraColors.oro,
    onTertiary: LitteraColors.tinta,
    error: LitteraColors.error,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: LitteraColors.tinta,
    onSurfaceVariant: Color(0xFF6B7084),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF6F6F9),
    surfaceContainer: Color(0xFFF2F2F6),
    surfaceContainerHigh: Color(0xFFECECF1),
    surfaceContainerHighest: Color(0xFFE6E6EC),
    outline: Color(0xFF9A9DAE),
    outlineVariant: Color(0xFFE6E6EC),
    shadow: Colors.black,
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
    onSurfaceVariant: Color(0xFF5A5A62),
    surfaceContainerLowest: LitteraColors.pergaminoClaro,
    surfaceContainerLow: Color(0xFFEEE3CB),
    surfaceContainer: LitteraColors.pergaminoMedio,
    surfaceContainerHigh: Color(0xFFE4D8BA),
    surfaceContainerHighest: LitteraColors.pergaminoOscuro,
    outline: Color(0xFF8C8670),
    outlineVariant: Color(0xFFD9CBA8),
    shadow: Color(0xFF5A4A28),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: LitteraColors.oro,
    onPrimary: LitteraColors.tinta,
    primaryContainer: Color(0xFF4A3D20),
    onPrimaryContainer: LitteraColors.pergamino,
    secondary: LitteraColors.oro,
    onSecondary: LitteraColors.tinta,
    secondaryContainer: Color(0xFF4A3F27),
    onSecondaryContainer: LitteraColors.pergamino,
    tertiary: LitteraColors.oro,
    onTertiary: LitteraColors.tinta,
    error: LitteraColors.errorClaro,
    onError: Color(0xFF601410),
    surface: LitteraColors.noche,
    onSurface: LitteraColors.pergamino,
    onSurfaceVariant: Color(0xFFB8B0A0),
    surfaceContainerLowest: Color(0xFF0C0B0A),
    surfaceContainerLow: LitteraColors.nocheCarta,
    surfaceContainer: LitteraColors.nocheMedia,
    surfaceContainerHigh: LitteraColors.nocheAlta,
    surfaceContainerHighest: LitteraColors.nocheBorde,
    outline: Color(0xFF8C857A),
    outlineVariant: LitteraColors.nocheBorde,
    shadow: Colors.black,
  );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
    );
    final text = base.textTheme;
    final cardColor = isDark ? LitteraColors.nocheCarta : Colors.white;
    const stadium = StadiumBorder();

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Tamaños explícitos: en este punto base.textTheme aún no los trae.
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      // Barra inferior de solo iconos (los nombres quedan para la
      // accesibilidad), con el activo en color.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.outline,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: stadium,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: stadium,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? LitteraColors.oro : LitteraColors.tinta,
          shape: stadium,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: stadium,
        elevation: 3,
      ),
      // Pestañas píldora: la elegida rellena en tinta, el resto solo texto.
      chipTheme: ChipThemeData(
        shape: stadium,
        side: BorderSide.none,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              // Pestañas sin elegir en tono cálido (pergamino), no gris.
              : isDark
              ? scheme.surfaceContainer
              : LitteraColors.pergamino.withValues(alpha: 0.6),
        ),
        // Flutter solo resuelve por estado el color del texto del chip (no
        // el estilo entero): fuente fija y color según si está elegido.
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusHero)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusHero),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? LitteraColors.pergamino : LitteraColors.tinta,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? LitteraColors.tinta : Colors.white,
        ),
        actionTextColor: LitteraColors.oro,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
