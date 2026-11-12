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

/// Ajustes globales de la app. Se guarda en Hive como un único registro.
class AppSettings {
  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.libraryGridView = true,
    this.librarySort = LibrarySort.recentlyAdded,
  });

  final AppThemePreference themePreference;
  final bool libraryGridView;
  final LibrarySort librarySort;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    bool? libraryGridView,
    LibrarySort? librarySort,
  }) => AppSettings(
    themePreference: themePreference ?? this.themePreference,
    libraryGridView: libraryGridView ?? this.libraryGridView,
    librarySort: librarySort ?? this.librarySort,
  );
}
