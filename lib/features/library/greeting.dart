// Saludo y frase de bienvenida de Inicio.

int _dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// Saludo según la hora.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 6 && h < 12) return 'Buenos días';
  if (h >= 12 && h < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

const _invitations = [
  '¿Qué historia te acompaña hoy?',
  'Un capítulo más nunca sobra.',
  'Tus libros te están esperando.',
  'Hoy es buen día para perderse entre páginas.',
  'Cada página es un pequeño viaje.',
];

/// Frase de bienvenida que cambia cada día.
String invitation([DateTime? now]) =>
    _invitations[_dayNumber(now ?? DateTime.now()) % _invitations.length];
