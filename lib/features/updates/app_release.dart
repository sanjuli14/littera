/// Una versión publicada en GitHub Releases.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.publishedAt,
    this.apkUrl,
    this.apkSize = 0,
  });

  /// `1.2.0` (sin la "v" de la etiqueta).
  final String version;
  final String name;

  /// Novedades (Markdown sencillo).
  final String notes;
  final DateTime publishedAt;

  /// Enlace al APK adjunto; `null` si la versión no trae APK.
  final String? apkUrl;
  final int apkSize;

  bool get hasApk => apkUrl != null;
}

/// `v1.2.0` / `1.2` / `1.2.0+5` → `[1, 2, 0]`.
List<int> parseVersion(String raw) {
  var v = raw.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  v = v.split('+').first.split('-').first;
  final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}

/// Negativo si [a] es anterior a [b], 0 si son iguales, positivo si posterior.
int compareVersions(String a, String b) {
  final pa = parseVersion(a), pb = parseVersion(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

/// Arquitecturas para las que se publica un APK propio.
const apkAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

/// Elige el APK para el móvil: el de su arquitectura [abi]; si no hay, uno
/// universal (sin arquitectura en el nombre); si tampoco, el primero.
Map<dynamic, dynamic>? pickApk(List<Map<dynamic, dynamic>> apks, String? abi) {
  if (apks.isEmpty) return null;
  String name(Map<dynamic, dynamic> a) => (a['name'] as String).toLowerCase();
  if (abi != null) {
    for (final a in apks) {
      if (name(a).contains(abi)) return a;
    }
  }
  for (final a in apks) {
    if (!apkAbis.any(name(a).contains)) return a;
  }
  return apks.first;
}

/// Convierte la respuesta de `GET /repos/{owner}/{repo}/releases`.
/// Ignora borradores, versiones previas y entradas mal formadas; ordena de
/// la más nueva a la más antigua. [abi] elige el APK de esa arquitectura.
List<AppRelease> parseReleases(Object? json, {String? abi}) {
  if (json is! List) return const [];
  final out = <AppRelease>[];
  for (final item in json) {
    if (item is! Map) continue;
    if (item['draft'] == true || item['prerelease'] == true) continue;
    final tag = item['tag_name'];
    if (tag is! String || tag.isEmpty) continue;

    final assets = item['assets'];
    final apk = pickApk([
      if (assets is List)
        for (final a in assets)
          if (a is Map &&
              a['name'] is String &&
              (a['name'] as String).toLowerCase().endsWith('.apk') &&
              a['browser_download_url'] is String)
            a,
    ], abi);
    final apkUrl = apk?['browser_download_url'] as String?;
    final apkSize = (apk?['size'] as num?)?.toInt() ?? 0;

    final version = parseVersion(tag).join('.');
    out.add(
      AppRelease(
        version: version,
        name: (item['name'] as String?)?.trim().isNotEmpty == true
            ? (item['name'] as String).trim()
            : 'Littera $version',
        notes: (item['body'] as String?)?.trim() ?? '',
        publishedAt:
            DateTime.tryParse(item['published_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        apkUrl: apkUrl,
        apkSize: apkSize,
      ),
    );
  }
  out.sort((a, b) => compareVersions(b.version, a.version));
  return out;
}
