import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;

import '../backup/backup_service.dart' show metaBoxProvider;
import '../library/import/book_metadata.dart' show looksLikeZip;
import '../updates/updates_provider.dart' show currentVersionProvider;
import 'gutenberg_book.dart';

class ExploreException implements Exception {
  const ExploreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Catálogo de Project Gutenberg a través de Gutendex.
///
/// Solo se conecta cuando el usuario abre Explorar, busca o descarga: no
/// envía nada de su biblioteca. Las respuestas se guardan un día para no
/// repetir consultas (Gutendex es un servicio gratuito y compartido).
class GutendexClient {
  GutendexClient({
    required this.client,
    required this.meta,
    required String appVersion,
    this.baseUrl = defaultBaseUrl,
    DateTime Function()? clock,
  }) : userAgent =
           'Littera/$appVersion (+https://github.com/sanjuli14/littera)',
       _clock = clock ?? DateTime.now;

  /// Servidor público. Para mucho tráfico conviene alojar uno propio
  /// (https://github.com/garethbjohnson/gutendex) y cambiar esta URL.
  static const defaultBaseUrl = 'https://gutendex.com';

  final http.Client client;
  final Box<dynamic> meta;
  final String baseUrl;
  final String userAgent;
  final DateTime Function() _clock;

  static const cacheTtl = Duration(hours: 24);
  static const _maxCacheEntries = 60;
  static const _cacheKey = 'exploreCache';
  static const _downloadsKey = 'gutenbergDownloads';

  /// Gutendex a veces tarda bastante en responder.
  static const _apiTimeout = Duration(seconds: 30);
  static const _downloadTimeout = Duration(minutes: 3);

  /// Libros por idioma (`es`, `en`… o `null` = todos), tema y búsqueda.
  /// Ordenados por popularidad.
  Future<GutendexPage> books({
    String? language,
    String? search,
    String? topic,
  }) {
    final text = search?.trim();
    final params = <String, String>{
      'languages': ?language,
      if (text != null && text.isNotEmpty) 'search': text,
      'topic': ?topic,
      // Solo dominio público.
      'copyright': 'false',
      'mime_type': 'application/epub',
    };
    final uri = Uri.parse('$baseUrl/books/').replace(queryParameters: params);
    return page(uri.toString());
  }

  /// Una página concreta (p. ej. el `next` de la anterior).
  Future<GutendexPage> page(String url) async {
    final json = await _getJson(url);
    if (json is! Map<String, dynamic>) {
      throw const ExploreException('Respuesta inesperada del catálogo.');
    }
    return GutendexPage.fromJson(json);
  }

  Future<GutenbergBook> book(int id) async {
    final json = await _getJson('$baseUrl/books/$id/');
    if (json is! Map<String, dynamic> || json['id'] == null) {
      throw const ExploreException('No se encontró el libro.');
    }
    return GutenbergBook.fromJson(json);
  }

  /// Descarga el EPUB del libro.
  Future<Uint8List> downloadEpub(GutenbergBook book) async {
    final url = book.epubUrl;
    if (url == null) {
      throw const ExploreException('Este libro no tiene versión EPUB.');
    }
    final http.Response response;
    try {
      response = await client
          .get(Uri.parse(url), headers: {'User-Agent': userAgent})
          .timeout(_downloadTimeout);
    } on TimeoutException {
      throw const ExploreException('La descarga tardó demasiado.');
    } catch (_) {
      throw const ExploreException('Sin conexión a internet.');
    }
    if (response.statusCode != 200) {
      throw ExploreException(
        'No se pudo descargar (error ${response.statusCode}).',
      );
    }
    final bytes = response.bodyBytes;
    if (!looksLikeZip(bytes)) {
      throw const ExploreException('El archivo descargado no es un EPUB.');
    }
    return bytes;
  }

  // ------------------------------------------- Libros ya descargados

  /// Id del libro de la biblioteca descargado desde este de Gutenberg.
  String? downloadedBookId(int gutenbergId) {
    final map = meta.get(_downloadsKey);
    return map is Map ? map['$gutenbergId'] as String? : null;
  }

  Future<void> markDownloaded(int gutenbergId, String bookId) {
    final map = Map<String, dynamic>.from(
      meta.get(_downloadsKey) as Map? ?? const {},
    );
    map['$gutenbergId'] = bookId;
    return meta.put(_downloadsKey, map);
  }

  // ------------------------------------------------------------ Red

  Future<Object?> _getJson(String url) async {
    final cached = _readCache(url);
    if (cached != null) return jsonDecode(cached);

    final http.Response response;
    try {
      response = await client
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/json', 'User-Agent': userAgent},
          )
          .timeout(_apiTimeout);
    } on TimeoutException {
      throw const ExploreException(
        'El catálogo tardó demasiado en responder. Inténtalo en un rato.',
      );
    } catch (_) {
      throw const ExploreException('Sin conexión a internet.');
    }
    if (response.statusCode == 404) {
      throw const ExploreException('No se encontró en el catálogo.');
    }
    if (response.statusCode != 200) {
      throw ExploreException(
        'El catálogo no está disponible (error ${response.statusCode}).',
      );
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const ExploreException('Respuesta inesperada del catálogo.');
    }
    await _writeCache(url, text);
    return json;
  }

  Map<String, dynamic> _cache() =>
      Map<String, dynamic>.from(meta.get(_cacheKey) as Map? ?? const {});

  String? _readCache(String url) {
    final entry = _cache()[url];
    if (entry is! Map) return null;
    final at = DateTime.tryParse(entry['at'] as String? ?? '');
    if (at == null || _clock().difference(at) >= cacheTtl) return null;
    return entry['body'] as String?;
  }

  Future<void> _writeCache(String url, String body) {
    final now = _clock();
    final cache = _cache()
      ..removeWhere((_, v) {
        final at = v is Map
            ? DateTime.tryParse(v['at'] as String? ?? '')
            : null;
        return at == null || now.difference(at) >= cacheTtl;
      });
    cache[url] = {'at': now.toIso8601String(), 'body': body};
    // Si aún hay demasiadas, fuera las más antiguas.
    if (cache.length > _maxCacheEntries) {
      final keys = cache.keys.toList()
        ..sort(
          (a, b) => ((cache[a] as Map)['at'] as String).compareTo(
            (cache[b] as Map)['at'] as String,
          ),
        );
      for (final k in keys.take(cache.length - _maxCacheEntries)) {
        cache.remove(k);
      }
    }
    return meta.put(_cacheKey, cache);
  }
}

final gutendexClientProvider = Provider<GutendexClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GutendexClient(
    client: client,
    meta: ref.watch(metaBoxProvider),
    appVersion: ref.watch(currentVersionProvider),
  );
});
