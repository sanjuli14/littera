import 'dart:convert';

final _word = RegExp(r"[\p{L}\p{N}]+(?:['’\-][\p{L}\p{N}]+)*", unicode: true);

/// Cuenta palabras ("dijo—no", "o'Neill" y "cómo-se-llama" cuentan bien).
int countWords(String text) => _word.allMatches(text).length;

/// Texto plano de un Delta de Quill (JSON). Ignora objetos incrustados.
String plainTextFromDelta(String deltaJson) {
  if (deltaJson.trim().isEmpty) return '';
  try {
    final ops = jsonDecode(deltaJson);
    if (ops is! List) return '';
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is Map && op['insert'] is String) buffer.write(op['insert']);
    }
    return buffer.toString();
  } catch (_) {
    return '';
  }
}

/// Clave de día local: `2026-11-12`.
String dayKey(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
