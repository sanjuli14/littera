import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/utils/box_stream.dart';
import '../../features/writing/word_count.dart';
import '../hive/hive_setup.dart';
import '../models/book.dart';
import 'library_repository.dart';
import 'writing_repository.dart';

/// Últimos [count] días, del más antiguo a hoy.
List<DateTime> lastDays(int count, DateTime today) => [
  for (var i = count - 1; i >= 0; i--)
    DateTime(today.year, today.month, today.day - i),
];

/// Lecturas y escritura agregadas por día.
class StatsRepository {
  StatsRepository({
    required this.readingLog,
    required this.writingLog,
    required this.books,
  });

  /// `'<bookId>|<día>'` → segundos.
  final Box<dynamic> readingLog;

  /// `'<manuscriptId>|<día>'` → `[inicio, fin]` (palabras).
  final Box<dynamic> writingLog;
  final Box<Book> books;

  // ---------------------------------------------------------------- Lectura

  Future<void> addReadingTime(String bookId, DateTime when, int seconds) async {
    if (seconds <= 0) return;
    final key = '$bookId|${dayKey(when)}';
    final previous = readingLog.get(key);
    await readingLog.put(key, (previous is int ? previous : 0) + seconds);
  }

  /// Segundos leídos por día (todas las obras).
  Map<String, int> readingSecondsByDay() {
    final out = <String, int>{};
    for (final key in readingLog.keys) {
      if (key is! String) continue;
      final value = readingLog.get(key);
      if (value is! int) continue;
      final day = key.substring(key.indexOf('|') + 1);
      out[day] = (out[day] ?? 0) + value;
    }
    return out;
  }

  int readingSecondsOn(DateTime day) => readingSecondsByDay()[dayKey(day)] ?? 0;

  int readingSecondsForBook(String bookId) => readingLog.keys
      .whereType<String>()
      .where((k) => k.startsWith('$bookId|'))
      .map((k) => readingLog.get(k))
      .whereType<int>()
      .fold(0, (a, b) => a + b);

  int readingSecondsInYear(int year) => readingSecondsByDay().entries
      .where((e) => e.key.startsWith('$year-'))
      .fold(0, (a, e) => a + e.value);

  List<Book> finishedInYear(int year) =>
      books.values.where((b) => b.finishedAt?.year == year).toList()
        ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

  // -------------------------------------------------------------- Escritura

  /// Palabras escritas por día (todas las obras; borrar no resta).
  Map<String, int> wordsByDay() {
    final out = <String, int>{};
    for (final key in writingLog.keys) {
      if (key is! String) continue;
      final value = writingLog.get(key);
      if (value is! List || value.length < 2) continue;
      final diff = (value[1] as int) - (value[0] as int);
      if (diff <= 0) continue;
      final day = key.substring(key.indexOf('|') + 1);
      out[day] = (out[day] ?? 0) + diff;
    }
    return out;
  }

  int wordsInYear(int year) => wordsByDay().entries
      .where((e) => e.key.startsWith('$year-'))
      .fold(0, (a, e) => a + e.value);
}

final readingLogBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>(HiveBoxes.readingLog),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    readingLog: ref.watch(readingLogBoxProvider),
    writingLog: ref.watch(writingLogBoxProvider),
    books: ref.watch(booksBoxProvider),
  ),
);

/// Cambia cada vez que se registra lectura (para refrescar la pantalla).
final readingLogProvider = StreamProvider<int>((ref) {
  final box = ref.watch(readingLogBoxProvider);
  return watchBox(box, () => box.length);
});
