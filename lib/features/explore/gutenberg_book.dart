/// Libros de Project Gutenberg tal como los sirve Gutendex
/// (https://gutendex.com). Son de dominio público y se descargan gratis.
library;

/// Réplica oficial de Project Gutenberg, con los mismos archivos.
const gutenbergMirror = 'https://gutenberg.pglaf.org';

/// Autor o traductor.
class GutenbergPerson {
  const GutenbergPerson({required this.name, this.birthYear, this.deathYear});

  factory GutenbergPerson.fromJson(Map<String, dynamic> json) =>
      GutenbergPerson(
        name: (json['name'] as String? ?? '').trim(),
        birthYear: (json['birth_year'] as num?)?.toInt(),
        deathYear: (json['death_year'] as num?)?.toInt(),
      );

  /// Como lo da Gutenberg: "Cervantes Saavedra, Miguel de".
  final String name;
  final int? birthYear;
  final int? deathYear;

  /// En orden natural: "Miguel de Cervantes Saavedra".
  String get displayName {
    final comma = name.indexOf(',');
    if (comma < 0) return name;
    final last = name.substring(0, comma).trim();
    // "Alighieri, Dante, 1265-1321" o "(Pseud.)": se queda la primera parte.
    final rest = name.substring(comma + 1).split(',').first.trim();
    if (rest.isEmpty) return last;
    return '$rest $last';
  }

  /// "1547–1616", "n. 1547" o vacío.
  String get lifespan {
    String year(int y) => y < 0 ? '${-y} a. C.' : '$y';
    final b = birthYear;
    final d = deathYear;
    if (b != null && d != null) return '${year(b)}–${year(d)}';
    if (b != null) return 'n. ${year(b)}';
    if (d != null) return 'm. ${year(d)}';
    return '';
  }
}

class GutenbergBook {
  const GutenbergBook({
    required this.id,
    required this.title,
    this.authors = const [],
    this.translators = const [],
    this.subjects = const [],
    this.bookshelves = const [],
    this.summaries = const [],
    this.languages = const [],
    this.copyright,
    this.formats = const {},
    this.downloadCount = 0,
  });

  factory GutenbergBook.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => v is List
        ? v.whereType<String>().map((s) => s.trim()).toList()
        : const [];
    List<GutenbergPerson> people(Object? v) => v is List
        ? v
              .whereType<Map<String, dynamic>>()
              .map(GutenbergPerson.fromJson)
              .where((p) => p.name.isNotEmpty)
              .toList()
        : const [];
    final formats = <String, String>{};
    final rawFormats = json['formats'];
    if (rawFormats is Map) {
      rawFormats.forEach((k, v) {
        if (k is String && v is String) formats[k] = v;
      });
    }
    return GutenbergBook(
      id: (json['id'] as num).toInt(),
      title: cleanTitle(json['title'] as String? ?? ''),
      authors: people(json['authors']),
      translators: people(json['translators']),
      subjects: strings(json['subjects']),
      bookshelves: strings(json['bookshelves']),
      summaries: strings(json['summaries']),
      languages: strings(json['languages']),
      copyright: json['copyright'] as bool?,
      formats: formats,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Número de libro en Project Gutenberg.
  final int id;
  final String title;
  final List<GutenbergPerson> authors;
  final List<GutenbergPerson> translators;
  final List<String> subjects;
  final List<String> bookshelves;

  /// Sinopsis (las genera Gutenberg, normalmente en inglés).
  final List<String> summaries;
  final List<String> languages;

  /// `false` = dominio público en EE. UU.
  final bool? copyright;

  /// Tipo MIME → URL de descarga.
  final Map<String, String> formats;
  final int downloadCount;

  String? get epubUrl => formats['application/epub+zip'];

  /// Dónde intentar la descarga, en orden: la réplica oficial de
  /// Gutenberg (EPUB3 y EPUB2) y después el enlace original.
  List<String> get epubUrls {
    final original = epubUrl;
    if (original == null) return const [];
    return [
      '$gutenbergMirror/cache/epub/$id/pg$id-images-3.epub',
      '$gutenbergMirror/cache/epub/$id/pg$id-images.epub',
      original,
    ];
  }

  /// Carátula servida desde la réplica (gutenberg.org a veces está caído).
  String? get coverUrl {
    final url = formats['image/jpeg'];
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'www.gutenberg.org') return url;
    return uri.replace(host: Uri.parse(gutenbergMirror).host).toString();
  }

  bool get canDownload => epubUrl != null;

  /// "Miguel de Cervantes Saavedra" o "Anónimo".
  String get authorLine => authors.isEmpty
      ? 'Anónimo'
      : authors.map((a) => a.displayName).join(', ');

  /// Nombre del archivo al importarlo: `Don Quijote.epub`.
  String get fileName {
    final safe = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final short = safe.length > 80 ? safe.substring(0, 80).trim() : safe;
    return '${short.isEmpty ? 'gutenberg-$id' : short}.epub';
  }
}

/// Algunos títulos traen el subtítulo en otra línea: se queda la primera.
String cleanTitle(String raw) {
  final first = raw
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  final title = first.replaceAll(RegExp(r'\s+'), ' ');
  return title.isEmpty ? 'Sin título' : title;
}

/// Una página de resultados de `/books`.
class GutendexPage {
  const GutendexPage({required this.count, required this.results, this.next});

  factory GutendexPage.fromJson(Map<String, dynamic> json) => GutendexPage(
    count: (json['count'] as num?)?.toInt() ?? 0,
    next: json['next'] as String?,
    results: (json['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GutenbergBook.fromJson)
        .toList(),
  );

  /// Total de libros de la consulta (todas las páginas).
  final int count;

  /// URL de la página siguiente, si la hay.
  final String? next;
  final List<GutenbergBook> results;
}
