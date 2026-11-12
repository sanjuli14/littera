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
    this.onboardingDone = false,
    this.readerSerif = true,
    this.reminderEnabled = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.nudgesEnabled = false,
  });

  final AppThemePreference themePreference;
  final bool libraryGridView;
  final LibrarySort librarySort;
  final ReaderTheme readerTheme;
  final double readerFontSize;
  final double readerLineHeight;
  final bool readerJustify;

  /// `true` cuando ya se vio la pantalla de bienvenida.
  final bool onboardingDone;

  /// Letra del lector: serif clásica (Lora) o sans moderna (Montserrat).
  final bool readerSerif;

  /// Recordatorio diario de lectura a [reminderHour]:[reminderMinute].
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// Avisar de libros a medias ("¡Ey, ya casi!").
  final bool nudgesEnabled;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    bool? libraryGridView,
    LibrarySort? librarySort,
    ReaderTheme? readerTheme,
    double? readerFontSize,
    double? readerLineHeight,
    bool? readerJustify,
    bool? onboardingDone,
    bool? readerSerif,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? nudgesEnabled,
  }) => AppSettings(
    themePreference: themePreference ?? this.themePreference,
    libraryGridView: libraryGridView ?? this.libraryGridView,
    librarySort: librarySort ?? this.librarySort,
    readerTheme: readerTheme ?? this.readerTheme,
    readerFontSize: readerFontSize ?? this.readerFontSize,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerJustify: readerJustify ?? this.readerJustify,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    readerSerif: readerSerif ?? this.readerSerif,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    nudgesEnabled: nudgesEnabled ?? this.nudgesEnabled,
  );
}
