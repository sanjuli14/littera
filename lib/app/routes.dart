abstract final class Routes {
  static const library = '/biblioteca';
  static const writing = '/escribir';
  static const settings = '/ajustes';
  static const backup = '$settings/copia';

  static String book(String id) => '$library/libro/$id';
  static const quotes = '/citas';

  /// Lector. [target] = bloque (EPUB/DOCX) o página (PDF) donde abrir.
  static String reader(String id, {int? target}) =>
      target == null ? '/leer/$id' : '/leer/$id?en=$target';
}
