/// Datos de la app. Mantener `appVersion` igual que `version` en pubspec.yaml.
abstract final class AppInfo {
  static const name = 'Littera';
  static const appVersion = '1.0.2';

  /// Quien la desarrolla, para contrataciones.
  static const developer = 'sanjuli14';
  static const developerPhone = '+53 5491 4231';
  static final developerWhatsApp = Uri.parse(
    'https://wa.me/5354914231?text='
    '${Uri.encodeComponent('Hola, vi Littera y me interesa contratarte.')}',
  );
}
