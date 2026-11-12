abstract final class Routes {
  static const library = '/biblioteca';
  static const writing = '/escribir';
  static const settings = '/ajustes';

  static String book(String id) => '$library/libro/$id';
}
