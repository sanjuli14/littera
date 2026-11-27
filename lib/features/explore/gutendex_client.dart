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
/// envía nada de su biblioteca.
///
/// Para que cargue rápido y no sature un servicio gratuito y compartido:
/// - como mucho [maxConcurrent] consultas a la vez (el resto espera en
///   cola) y una misma URL nunca se pide dos veces en paralelo;
/// - lo guardado se muestra al instante: si tiene menos de [cacheTtl] no se
///   consulta; si es más viejo (hasta [staleTtl]) se muestra y se refresca
///   en segundo plano, y también sirve de respaldo si el catálogo falla.
class GutendexClient {
  GutendexClient({
    required this.client,
    required this.meta,
    required String appVersion,
    this.baseUrl = defaultBaseUrl,
    DateTime Function()? clock,
    this.retryDelay = const Duration(seconds: 2),
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

  /// Espera antes de reintentar un fallo del servidor.
  final Duration retryDelay;

  static const cacheTtl = Duration(hours: 24);
  static const staleTtl = Duration(days: 7);
  static const maxConcurrent = 2;
  static const _maxCacheEntries = 80;
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

  /// Descarga el EPUB del libro. Prueba primero la réplica oficial
  /// (gutenberg.pglaf.org) y luego gutenberg.org, que a veces está en
  /// mantenimiento (error 503).
  Future<Uint8List> downloadEpub(GutenbergBook book) async {
    final urls = book.epubUrls;
    if (urls.isEmpty) {
      throw const ExploreException('Este libro no tiene versión EPUB.');
    }
    ExploreException? last;
    for (final url in urls) {
      try {
        return await _downloadFrom(url);
      } on ExploreException catch (e) {
        last = e;
      }
    }
    throw last!;
  }

  Future<Uint8List> _downloadFrom(String url) async {
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
    if (response.statusCode >= 500) {
      throw const ExploreException(
        'Project Gutenberg no está disponible ahora mismo. '
        'Inténtalo en un rato.',
      );
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

  /// Consultas en curso o en cola, por URL (para no repetirlas).
  final _inFlight = <String, Future<String>>{};
  final _waiting = <Completer<void>>[];
  var _running = 0;

  Future<Object?> _getJson(String url) async {
    final cached = _readCache(url);
    if (cached != null) {
      if (cached.stale) {
        // Se muestra lo guardado y se actualiza para la próxima vez.
        unawaited(_fetch(url).then((_) {}, onError: (_) {}));
      }
      return jsonDecode(cached.body);
    }
    return jsonDecode(await _fetch(url));
  }

  Future<String> _fetch(String url) =>
      _inFlight[url] ??= _queued(() => _download(url)).whenComplete(() {
        // Sin devolver el Future: whenComplete lo esperaría a sí mismo.
        _inFlight.remove(url);
      });

  /// Ejecuta [task] cuando haya un hueco (máximo [maxConcurrent]).
  Future<T> _queued<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }

  /// Pide la URL (un reintento si el servidor falla) y la guarda.
  Future<String> _download(String url) async {
    http.Response response;
    try {
      response = await _get(url);
      if (response.statusCode >= 500) {
        await Future<void>.delayed(retryDelay);
        response = await _get(url);
      }
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
    try {
      jsonDecode(text);
    } on FormatException {
      throw const ExploreException('Respuesta inesperada del catálogo.');
    }
    await _writeCache(url, text);
    return text;
  }

  Future<http.Response> _get(String url) => client
      .get(
        Uri.parse(url),
        headers: {'Accept': 'application/json', 'User-Agent': userAgent},
      )
      .timeout(_apiTimeout);

  Map<String, dynamic> _cache() =>
      Map<String, dynamic>.from(meta.get(_cacheKey) as Map? ?? const {});

  ({String body, bool stale})? _readCache(String url) {
    final entry = _cache()[url];
    if (entry is! Map) return null;
    final at = DateTime.tryParse(entry['at'] as String? ?? '');
    final body = entry['body'];
    if (at == null || body is! String) return null;
    final age = _clock().difference(at);
    if (age >= staleTtl) return null;
    return (body: body, stale: age >= cacheTtl);
  }

  Future<void> _writeCache(String url, String body) {
    final now = _clock();
    final cache = _cache()
      ..removeWhere((_, v) {
        final at = v is Map
            ? DateTime.tryParse(v['at'] as String? ?? '')
            : null;
        return at == null || now.difference(at) >= staleTtl;
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
