/// Apariencia elegida por el usuario.
enum AppThemePreference { system, light, sepia, dark }

/// Orden de la biblioteca.
enum LibrarySort {
  recentlyAdded,
  recentlyOpened,
  title,
  author;

  String get label => switch (this) {
    LibrarySort.recentlyAdded => 'Añadidos recientemente',
    LibrarySort.recentlyOpened => 'Leídos recientemente',
    LibrarySort.title => 'Título',
    LibrarySort.author => 'Autor',
  };
}

/// Tema del lector. [auto] sigue el tema de la app.
enum ReaderTheme {
  auto,
  light,
  sepia,
  dark;

  String get label => switch (this) {
    ReaderTheme.auto => 'Auto',
    ReaderTheme.light => 'Claro',
    ReaderTheme.sepia => 'Sepia',
    ReaderTheme.dark => 'Oscuro',
  };
}

/// Límites de los ajustes del lector.
abstract final class ReaderLimits {
  static const minFontSize = 14.0;
  static const maxFontSize = 32.0;
  static const minLineHeight = 1.2;
  static const maxLineHeight = 2.2;
}

/// Ajustes globales de la app. Se guarda en Hive como un único registro.
class AppSettings {
  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.libraryGridView = true,
    this.librarySort = LibrarySort.recentlyAdded,
    this.readerTheme = ReaderTheme.auto,
    this.readerFontSize = 18,
    this.readerLineHeight = 1.6,
    this.readerJustify = true,
    this.annualBookGoal = 12,
    this.dailyReadingMinutes = 20,
    this.onboardingDone = false,
    this.readerSerif = true,
  });

  final AppThemePreference themePreference;
  final bool libraryGridView;
  final LibrarySort librarySort;
  final ReaderTheme readerTheme;
  final double readerFontSize;
  final double readerLineHeight;
  final bool readerJustify;

  /// Meta de libros terminados al año (0 = sin meta).
  final int annualBookGoal;

  /// Meta de minutos de lectura al día (0 = sin meta).
  final int dailyReadingMinutes;

  /// `true` cuando ya se vio la pantalla de bienvenida.
  final bool onboardingDone;

  /// Letra del lector: serif clásica (Lora) o sans moderna (Montserrat).
  final bool readerSerif;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    bool? libraryGridView,
    LibrarySort? librarySort,
    ReaderTheme? readerTheme,
    double? readerFontSize,
    double? readerLineHeight,
    bool? readerJustify,
    int? annualBookGoal,
    int? dailyReadingMinutes,
    bool? onboardingDone,
    bool? readerSerif,
  }) => AppSettings(
    themePreference: themePreference ?? this.themePreference,
    libraryGridView: libraryGridView ?? this.libraryGridView,
    librarySort: librarySort ?? this.librarySort,
    readerTheme: readerTheme ?? this.readerTheme,
    readerFontSize: readerFontSize ?? this.readerFontSize,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerJustify: readerJustify ?? this.readerJustify,
    annualBookGoal: annualBookGoal ?? this.annualBookGoal,
    dailyReadingMinutes: dailyReadingMinutes ?? this.dailyReadingMinutes,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    readerSerif: readerSerif ?? this.readerSerif,
  );
}
