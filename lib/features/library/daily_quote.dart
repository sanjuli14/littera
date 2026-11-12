import '../../data/models/highlight.dart';

/// Cita para la portada.
class DailyQuote {
  const DailyQuote(this.text, this.source, {this.highlight});

  final String text;
  final String source;

  /// Si viene de tus subrayados, para abrir el libro en ella.
  final Highlight? highlight;
}

/// Clásicos en español de dominio público.
const classicQuotes = [
  DailyQuote(
    'El que lee mucho y anda mucho, ve mucho y sabe mucho.',
    'Miguel de Cervantes · Don Quijote',
  ),
  DailyQuote(
    'Caminante, no hay camino, se hace camino al andar.',
    'Antonio Machado · Proverbios y cantares',
  ),
  DailyQuote(
    'Volverán las oscuras golondrinas en tu balcón sus nidos a colgar.',
    'Gustavo Adolfo Bécquer · Rima LIII',
  ),
  DailyQuote(
    'Toda la vida es sueño, y los sueños, sueños son.',
    'Pedro Calderón de la Barca · La vida es sueño',
  ),
  DailyQuote(
    'Juventud, divino tesoro, ¡ya te vas para no volver!',
    'Rubén Darío · Canción de otoño en primavera',
  ),
  DailyQuote(
    'Yo soy un hombre sincero de donde crece la palma.',
    'José Martí · Versos sencillos',
  ),
  DailyQuote(
    'Hombres necios que acusáis a la mujer sin razón, sin ver que sois la '
        'ocasión de lo mismo que culpáis.',
    'Sor Juana Inés de la Cruz · Redondillas',
  ),
  DailyQuote(
    'Ande yo caliente, y ríase la gente.',
    'Luis de Góngora · Letrillas',
  ),
];

int _dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// La cita de hoy: una de tus citas (que cambia cada día) o un clásico.
DailyQuote quoteOfTheDay(
  List<Highlight> highlights,
  String Function(String bookId) bookTitle, {
  DateTime? now,
}) {
  final day = _dayNumber(now ?? DateTime.now());
  final mine =
      highlights
          .where((h) => h.text.length >= 25 && h.text.length <= 260)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  if (mine.isNotEmpty) {
    final h = mine[day % mine.length];
    return DailyQuote(h.text, bookTitle(h.bookId), highlight: h);
  }
  return classicQuotes[day % classicQuotes.length];
}

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
