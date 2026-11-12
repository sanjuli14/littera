import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_release.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Busca versiones nuevas en GitHub Releases, las descarga e instala.
///
/// Solo consulta la lista pública de versiones: no envía ningún dato del
/// usuario ni de su biblioteca.
class UpdateService {
  UpdateService({
    required this.client,
    required this.meta,
    required this.currentVersion,
    this.repository = 'sanjuli14/littera',
    Future<Directory> Function()? downloadsDir,
    Future<bool> Function(String path)? openInstaller,
  }) : _downloadsDir = downloadsDir ?? getTemporaryDirectory,
       _openInstaller = openInstaller ?? _openWithSystem;

  final http.Client client;
  final Box<dynamic> meta;
  final String currentVersion;
  final String repository;
  final Future<Directory> Function() _downloadsDir;
  final Future<bool> Function(String path) _openInstaller;

  /// Como mucho una consulta automática al día.
  static const checkInterval = Duration(hours: 24);

  static const _cacheKey = 'releasesCache';
  static const _lastCheckKey = 'lastUpdateCheck';
  static const _dismissedKey = 'dismissedUpdate';
  static const _notifiedKey = 'notifiedUpdate';

  Uri get _releasesUri => Uri.parse(
    'https://api.github.com/repos/$repository/releases?per_page=30',
  );

  /// Versiones guardadas de la última consulta (para verlas sin conexión).
  List<AppRelease> cachedReleases() {
    final raw = meta.get(_cacheKey);
    if (raw is! String) return const [];
    try {
      return parseReleases(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  bool shouldCheck(DateTime now) {
    final last = DateTime.tryParse(meta.get(_lastCheckKey) as String? ?? '');
    return last == null || now.difference(last) >= checkInterval;
  }

  /// Descarga la lista de versiones y la guarda.
  Future<List<AppRelease>> fetchReleases({DateTime? now}) async {
    final http.Response response;
    try {
      response = await client
          .get(
            _releasesUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Littera-app',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const UpdateException('La conexión tardó demasiado.');
    } catch (_) {
      throw const UpdateException('Sin conexión a internet.');
    }
    if (response.statusCode != 200) {
      throw UpdateException(
        'No se pudo consultar (error ${response.statusCode}).',
      );
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final releases = parseReleases(jsonDecode(text));
    await meta.put(_cacheKey, text);
    await meta.put(_lastCheckKey, (now ?? DateTime.now()).toIso8601String());
    return releases;
  }

  /// La versión más nueva con APK que sea posterior a la instalada.
  AppRelease? newestUpdate(List<AppRelease> releases) => releases
      .where((r) => r.hasApk && compareVersions(r.version, currentVersion) > 0)
      .firstOrNull;

  // ------------------------------------------------- Avisos ya mostrados

  bool isDismissed(String version) => meta.get(_dismissedKey) == version;
  Future<void> dismiss(String version) => meta.put(_dismissedKey, version);

  /// `true` la primera vez para cada versión (para notificar una sola vez).
  Future<bool> markNotified(String version) async {
    if (meta.get(_notifiedKey) == version) return false;
    await meta.put(_notifiedKey, version);
    return true;
  }

  // ------------------------------------------------ Descarga e instalación

  /// Descarga el APK informando el progreso (0–1). Devuelve el archivo.
  Future<File> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final url = release.apkUrl;
    if (url == null) throw const UpdateException('Esta versión no trae APK.');
    final dir = await _downloadsDir();
    final file = File(p.join(dir.path, 'littera-${release.version}.apk'));

    final http.StreamedResponse response;
    try {
      response = await client.send(
        http.Request('GET', Uri.parse(url))
          ..headers['User-Agent'] = 'Littera-app',
      );
    } catch (_) {
      throw const UpdateException('Sin conexión a internet.');
    }
    if (response.statusCode != 200) {
      throw UpdateException(
        'La descarga falló (error ${response.statusCode}).',
      );
    }

    final total = response.contentLength ?? release.apkSize;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1));
      }
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw const UpdateException('La descarga se interrumpió.');
    }
    await sink.close();
    if (total > 0 && received < total) {
      await file.delete();
      throw const UpdateException('La descarga llegó incompleta.');
    }
    onProgress?.call(1);
    return file;
  }

  /// Abre el instalador de Android con el APK descargado.
  Future<void> install(File apk) async {
    final ok = await _openInstaller(apk.path);
    if (!ok) {
      throw const UpdateException(
        'No se pudo abrir el instalador. Permite a Littera instalar apps '
        'en los ajustes del móvil y vuelve a intentarlo.',
      );
    }
  }

  static Future<bool> _openWithSystem(String path) async {
    if (kIsWeb) return false;
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }
}
