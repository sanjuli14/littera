import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../hive/hive_setup.dart';
import '../models/highlight.dart';

class HighlightsRepository {
  HighlightsRepository(this.box);

  final Box<Highlight> box;
  static const _uuid = Uuid();

  Stream<List<Highlight>> watchAll() async* {
    yield box.values.toList();
    yield* box.watch().map((_) => box.values.toList());
  }

  List<Highlight> forBook(String bookId) =>
      box.values.where((h) => h.bookId == bookId).toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  /// Subrayado en un bloque de EPUB/DOCX. Si se solapa con otros del mismo
  /// bloque, se fusionan en uno (conservando la nota más reciente).
  Future<Highlight> addBlockHighlight({
    required String bookId,
    required int blockIndex,
    required int start,
    required int end,
    required String blockText,
    HighlightColor color = HighlightColor.oro,
    String? note,
  }) async {
    var s = start, e = end;
    String? mergedNote = note;
    final overlapping = box.values
        .where(
          (h) =>
              h.bookId == bookId &&
              h.blockIndex == blockIndex &&
              h.start != null &&
              h.end != null &&
              h.start! < e &&
              h.end! > s,
        )
        .toList();
    for (final h in overlapping) {
      if (h.start! < s) s = h.start!;
      if (h.end! > e) e = h.end!;
      if (mergedNote == null && h.hasNote) mergedNote = h.note;
      await box.delete(h.id);
    }
    s = s.clamp(0, blockText.length);
    e = e.clamp(s, blockText.length);

    final highlight = Highlight(
      id: _uuid.v4(),
      bookId: bookId,
      text: blockText.substring(s, e).trim(),
      blockIndex: blockIndex,
      start: s,
      end: e,
      color: color,
      note: mergedNote,
      createdAt: DateTime.now(),
    );
    await box.put(highlight.id, highlight);
    return highlight;
  }

  /// Cita o nota en una página de PDF.
  Future<Highlight> addPageHighlight({
    required String bookId,
    required int page,
    String text = '',
    String? note,
    HighlightColor color = HighlightColor.oro,
  }) async {
    final highlight = Highlight(
      id: _uuid.v4(),
      bookId: bookId,
      text: text.trim(),
      page: page,
      note: note,
      color: color,
      createdAt: DateTime.now(),
    );
    await box.put(highlight.id, highlight);
    return highlight;
  }

  Future<void> update(Highlight highlight) => box.put(highlight.id, highlight);

  Future<void> delete(String id) => box.delete(id);

  Future<void> deleteForBook(String bookId) => box.deleteAll(
    box.values.where((h) => h.bookId == bookId).map((h) => h.id).toList(),
  );
}

final highlightsBoxProvider = Provider<Box<Highlight>>(
  (ref) => Hive.box<Highlight>(HiveBoxes.highlights),
);

final highlightsRepositoryProvider = Provider<HighlightsRepository>(
  (ref) => HighlightsRepository(ref.watch(highlightsBoxProvider)),
);

final allHighlightsProvider = StreamProvider<List<Highlight>>(
  (ref) => ref.watch(highlightsRepositoryProvider).watchAll(),
);

/// Subrayados de un libro, en orden de lectura.
final bookHighlightsProvider = Provider.family<List<Highlight>, String>((
  ref,
  bookId,
) {
  final all = ref.watch(allHighlightsProvider).value ?? const <Highlight>[];
  return all.where((h) => h.bookId == bookId).toList()
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
});
