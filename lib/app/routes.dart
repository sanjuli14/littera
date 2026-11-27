abstract final class Routes {
  static const library = '/biblioteca';
  static const writing = '/escribir';
  static const explore = '/explorar';

  static String exploreBook(int id) => '$explore/libro/$id';

  /// "Ver todo" de una sección de Explorar. [topic] `null` = más leídos.
  static String exploreTopic({String? topic, required String title}) => Uri(
    path: '$explore/tema',
    queryParameters: {'titulo': title, 'tema': ?topic},
  ).toString();
  static const settings = '/ajustes';
  static const backup = '$settings/copia';
  static const whatsNew = '$settings/novedades';

  static String book(String id) => '$library/libro/$id';
  static const quotes = '/citas';
  static const stats = '/estadisticas';
  static const welcome = '/bienvenida';

  static String manuscript(String id) => '$writing/obra/$id';
  static String chapterEditor(String chapterId) => '/editor/$chapterId';

  /// Lector. [target] = bloque (EPUB/DOCX) o página (PDF) donde abrir.
  static String reader(String id, {int? target}) =>
      target == null ? '/leer/$id' : '/leer/$id?en=$target';
}
