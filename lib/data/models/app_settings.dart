/// Apariencia elegida por el usuario.
enum AppThemePreference { system, light, sepia, dark }

/// Ajustes globales de la app. Se guarda en Hive como un único registro.
class AppSettings {
  const AppSettings({this.themePreference = AppThemePreference.system});

  final AppThemePreference themePreference;

  AppSettings copyWith({AppThemePreference? themePreference}) =>
      AppSettings(themePreference: themePreference ?? this.themePreference);
}
