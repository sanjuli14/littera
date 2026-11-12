import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/core/storage/file_store.dart';
import 'package:littera/data/models/book.dart';
import 'package:littera/data/repositories/library_repository.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late TestEnv env;
  late LibraryRepository repo;

  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  setUp(() async {
    env = await TestEnv.create();
    repo = env.repository;
  });

  test('estado de lectura y datos editables', () async {
    final book = testBook();
    await repo.saveBook(book);
    await repo.setStatus(book, ReadingStatus.reading);
    await repo.updateDetails(
      repo.getBook('b1')!,
      title: 'Nuevo',
      author: 'Otro',
    );

    final saved = repo.getBook('b1')!;
    expect(saved.status, ReadingStatus.reading);
    expect(saved.title, 'Nuevo');
    expect(saved.author, 'Otro');
  });

  test('estantes: crear, evitar duplicados, renombrar y ordenar', () async {
    final a = await repo.createShelf('  Favoritos ');
    final b = await repo.createShelf('Clásicos');
    expect(a!.name, 'Favoritos');
    expect(await repo.createShelf('favoritos'), isNull);
    expect(await repo.createShelf('   '), isNull);
    expect(b!.order, greaterThan(a.order));

    expect(await repo.renameShelf(b, 'Favoritos'), isFalse);
    expect(await repo.renameShelf(b, 'Poesía'), isTrue);
    expect(env.shelves.get(b.id)!.name, 'Poesía');
  });

  test(
    'añadir y quitar libro de un estante; borrar estante lo limpia',
    () async {
      final shelf = (await repo.createShelf('Favoritos'))!;
      await repo.saveBook(testBook());
      await repo.toggleShelf(repo.getBook('b1')!, shelf.id);
      expect(repo.getBook('b1')!.shelfIds, [shelf.id]);

      await repo.deleteShelf(shelf);
      expect(repo.getBook('b1')!.shelfIds, isEmpty);
      expect(env.shelves.isEmpty, isTrue);
    },
  );

  test(
    'carátula personalizada reemplaza la anterior y se puede quitar',
    () async {
      await repo.saveBook(testBook());
      expect(await repo.setCover(repo.getBook('b1')!, pngBytes()), isTrue);
      final first = repo.getBook('b1')!.coverRef!;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.setCover(repo.getBook('b1')!, pngBytes(width: 50));

      final book = repo.getBook('b1')!;
      expect(book.hasCustomCover, isTrue);
      expect(book.coverRef, isNot(first));
      expect(env.files.files.containsKey(first), isFalse);

      await repo.removeCover(book);
      expect(repo.getBook('b1')!.coverRef, isNull);
      expect(env.files.files, isEmpty);
    },
  );

  test('una imagen inválida no cambia la carátula', () async {
    await repo.saveBook(testBook());
    final ok = await repo.setCover(repo.getBook('b1')!, pdfBytes);
    expect(ok, isFalse);
    expect(repo.getBook('b1')!.coverRef, isNull);
  });

  test('eliminar libro borra archivo y carátula', () async {
    await env.files.write(FileArea.books, 'b1.epub', pdfBytes);
    await repo.saveBook(testBook());
    await repo.setCover(repo.getBook('b1')!, pngBytes());

    await repo.deleteBook(repo.getBook('b1')!);
    expect(env.books.isEmpty, isTrue);
    expect(env.files.files, isEmpty);
  });

  test('cambios con una copia vieja del libro no pisan otros datos', () async {
    final stale = testBook();
    await repo.saveBook(stale);
    await repo.saveProgress('b1', 'b:50', 0.5); // p. ej. desde el lector
    await repo.setStatus(stale, ReadingStatus.finished);
    await repo.updateDetails(stale, title: 'Nuevo');
    final book = repo.getBook('b1')!;
    expect(book.position, 'b:50');
    expect(book.progress, 0.5);
    expect(book.status, ReadingStatus.finished);
    expect(book.title, 'Nuevo');
  });

  test('valoración: 1 a 5 estrellas; tocar la misma la quita', () async {
    await repo.saveBook(testBook());
    await repo.setRating(repo.getBook('b1')!, 4);
    expect(repo.getBook('b1')!.rating, 4);
    await repo.setRating(repo.getBook('b1')!, 4);
    expect(repo.getBook('b1')!.rating, 0);
    await repo.setRating(repo.getBook('b1')!, 9);
    expect(repo.getBook('b1')!.rating, 5);
  });
}
