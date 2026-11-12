import '../../data/models/book.dart';

/// Texto de una notificación. [bookId] = libro que se abre al tocarla.
class ReminderMessage {
  const ReminderMessage(this.title, this.body, {this.bookId});

  final String title;
  final String body;
  final String? bookId;

  String? get payload => bookId == null ? null : 'book:$bookId';

  static String? bookIdFromPayload(String? payload) =>
      payload != null && payload.startsWith('book:')
      ? payload.substring(5)
      : null;
}

/// Empujón programado para una fecha concreta.
class NudgePlan {
  const NudgePlan(this.when, this.message);
  final DateTime when;
  final ReminderMessage message;
}

/// Días sin abrir un libro a medias antes de recordarlo.
const nudgeAfterDays = 3;

Book? _lastReading(List<Book> books) {
  final reading =
      books
          .where(
            (b) => b.status == ReadingStatus.reading && b.lastOpenedAt != null,
          )
          .toList()
        ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
  return reading.firstOrNull;
}

String _percent(Book b) => '${(b.progress * 100).round()} %';

/// Aviso diario: invita a seguir con el libro en curso o a empezar uno.
ReminderMessage dailyReminderMessage(List<Book> books) {
  final current = _lastReading(books);
  if (current != null) {
    return ReminderMessage(
      'Tu rato de lectura',
      current.progress > 0
          ? '«${current.title}» te espera: vas por el ${_percent(current)}.'
          : '«${current.title}» te espera. ¿Leemos un poco?',
      bookId: current.id,
    );
  }
  final next = books.where((b) => b.status == ReadingStatus.toRead).toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  if (next.isNotEmpty) {
    return ReminderMessage(
      'Tu rato de lectura',
      '¿Y si hoy empiezas «${next.first.title}»?',
      bookId: next.first.id,
    );
  }
  return const ReminderMessage(
    'Tu rato de lectura',
    'Unas páginas antes de dormir sientan bien.',
  );
}

/// "Ey, termina tal libro": el libro a medias más avanzado, recordado
/// [nudgeAfterDays] días después de la última vez que se abrió, a la hora
/// del recordatorio. `null` si no hay ninguno.
NudgePlan? finishNudge(
  List<Book> books, {
  required DateTime now,
  required int hour,
  required int minute,
}) {
  final candidates =
      books
          .where(
            (b) =>
                b.status == ReadingStatus.reading &&
                b.lastOpenedAt != null &&
                b.progress >= 0.1 &&
                b.progress < 1,
          )
          .toList()
        ..sort((a, b) => b.progress.compareTo(a.progress));
  final book = candidates.firstOrNull;
  if (book == null) return null;

  final due = book.lastOpenedAt!.add(const Duration(days: nudgeAfterDays));
  var when = DateTime(due.year, due.month, due.day, hour, minute);
  if (when.isBefore(due)) when = when.add(const Duration(days: 1));
  if (!when.isAfter(now)) {
    // Ya pasó el plazo: el próximo hueco a esa hora.
    when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
  }

  final message = book.progress >= 0.8
      ? ReminderMessage(
          '¡Ey, ya casi!',
          'Te falta muy poco para terminar «${book.title}» '
              '(${_percent(book)}). ¿Lo acabamos hoy?',
          bookId: book.id,
        )
      : ReminderMessage(
          '¿Seguimos con «${book.title}»?',
          'Lo dejaste en el ${_percent(book)}. La historia te está esperando.',
          bookId: book.id,
        );
  return NudgePlan(when, message);
}
