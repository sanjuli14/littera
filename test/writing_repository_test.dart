import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/data/models/manuscript.dart';
import 'package:littera/data/repositories/writing_repository.dart';
import 'package:littera/features/writing/word_count.dart';

import 'helpers.dart';

/// Delta de Quill con un párrafo.
String delta(String text) => jsonEncode([
  {'insert': '$text\n'},
]);

void main() {
  late Directory dir;
  late TestEnv env;
  late WritingRepository repo;

  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  setUp(() async {
    env = await TestEnv.create();
    repo = env.writingRepository;
  });

  group('contar palabras', () {
    test('palabras con tildes, guiones, apóstrofos y números', () {
      expect(countWords(''), 0);
      expect(countWords('  Hola,   mundo. '), 2);
      expect(countWords('—¿Cómo estás? —dijo Ñoño.'), 4);
      expect(countWords("Va a casa-cuna de O'Neill en 1984"), 7);
    });

    test('texto plano desde un Delta, ignorando incrustados', () {
      final json = jsonEncode([
        {'insert': 'Uno '},
        {
          'insert': 'dos',
          'attributes': {'bold': true},
        },
        {
          'insert': {'image': 'x.png'},
        },
        {'insert': '\n'},
      ]);
      expect(plainTextFromDelta(json), 'Uno dos\n');
      expect(plainTextFromDelta('basura'), '');
    });
  });

  test('un manuscrito nuevo trae su primer capítulo', () async {
    final m = await repo.createManuscript('  Mi novela ');
    expect(m.title, 'Mi novela');
    final chapters = repo.chaptersOf(m.id);
    expect(chapters.single.title, 'Capítulo 1');
    expect((await repo.createManuscript('')).title, 'Sin título');
  });

  test('capítulos: añadir, renombrar, reordenar y borrar', () async {
    final m = await repo.createManuscript('Libro');
    final c2 = await repo.addChapter(m.id);
    final c3 = await repo.addChapter(m.id, title: 'Epílogo');
    expect(repo.chaptersOf(m.id).map((c) => c.title), [
      'Capítulo 1',
      'Capítulo 2',
      'Epílogo',
    ]);

    final ids = repo.chaptersOf(m.id).map((c) => c.id).toList();
    await repo.reorderChapters(m.id, [ids[2], ids[0], ids[1]]);
    expect(repo.chaptersOf(m.id).map((c) => c.title).first, 'Epílogo');

    await repo.renameChapter(c2, 'El viaje');
    await repo.deleteChapter(c3);
    expect(repo.chaptersOf(m.id).map((c) => c.title), [
      'Capítulo 1',
      'El viaje',
    ]);
  });

  test('guardar cuenta palabras y lleva la cuenta del día', () async {
    final m = await repo.createManuscript('Libro');
    final c = repo.chaptersOf(m.id).single;
    final day1 = DateTime(2026, 11, 12, 10);

    await repo.saveChapterContent(c.id, delta('uno dos tres'), now: day1);
    await repo.saveChapterContent(
      c.id,
      delta('uno dos tres cuatro cinco'),
      now: day1,
    );
    expect(env.chapters.get(c.id)!.wordCount, 5);
    expect(repo.totalWords(m.id), 5);
    expect(repo.wordsToday(m.id, now: day1), 5);

    // Al día siguiente la cuenta empieza en cero.
    final day2 = DateTime(2026, 11, 13, 9);
    expect(repo.wordsToday(m.id, now: day2), 0);
    await repo.saveChapterContent(
      c.id,
      delta('uno dos tres cuatro cinco seis'),
      now: day2,
    );
    expect(repo.wordsToday(m.id, now: day2), 1);

    // Borrar texto no da números negativos.
    await repo.saveChapterContent(c.id, delta('uno'), now: day2);
    expect(repo.wordsToday(m.id, now: day2), 0);
  });

  group('versiones', () {
    test('no duplica versiones automáticas idénticas', () async {
      final m = await repo.createManuscript('Libro');
      final c = repo.chaptersOf(m.id).single;
      expect(await repo.snapshot(c.id), isNull); // vacío
      await repo.saveChapterContent(c.id, delta('borrador'));
      expect(await repo.snapshot(c.id), isNotNull);
      expect(await repo.snapshot(c.id), isNull);
      expect(await repo.snapshot(c.id, manual: true, label: 'Hito'), isNotNull);
      expect(repo.versionsOf(c.id).first.label, 'Hito');
    });

    test('limita las automáticas y conserva las manuales', () async {
      final m = await repo.createManuscript('Libro');
      final c = repo.chaptersOf(m.id).single;
      await repo.saveChapterContent(c.id, delta('manual'));
      await repo.snapshot(c.id, manual: true);
      for (var i = 0; i < maxAutoVersions + 5; i++) {
        await repo.saveChapterContent(c.id, delta('versión $i'));
        await repo.snapshot(c.id);
      }
      final all = repo.versionsOf(c.id);
      expect(all.where((v) => !v.manual), hasLength(maxAutoVersions));
      expect(all.where((v) => v.manual), hasLength(1));
    });

    test('restaurar guarda antes el estado actual', () async {
      final m = await repo.createManuscript('Libro');
      final c = repo.chaptersOf(m.id).single;
      await repo.saveChapterContent(c.id, delta('primera idea'));
      final v1 = (await repo.snapshot(c.id, manual: true))!;
      await repo.saveChapterContent(c.id, delta('texto que luego no me gustó'));

      await repo.restoreVersion(v1);
      expect(env.chapters.get(c.id)!.content, delta('primera idea'));
      expect(
        repo.versionsOf(c.id).map((v) => v.content),
        contains(delta('texto que luego no me gustó')),
      );
    });
  });

  test('fichas ordenadas por tipo y nombre', () async {
    final m = await repo.createManuscript('Libro');
    await repo.addEntity(m.id, kind: EntityKind.place, name: 'Macondo');
    await repo.addEntity(m.id, kind: EntityKind.character, name: 'úrsula');
    await repo.addEntity(m.id, kind: EntityKind.character, name: 'Aureliano');
    expect(repo.entitiesOf(m.id).map((e) => e.name), [
      'Aureliano',
      'úrsula',
      'Macondo',
    ]);
  });

  test('borrar un manuscrito borra todo lo suyo', () async {
    final m = await repo.createManuscript('Libro');
    final other = await repo.createManuscript('Otro');
    final c = repo.chaptersOf(m.id).single;
    await repo.saveChapterContent(c.id, delta('texto'));
    await repo.snapshot(c.id, manual: true);
    await repo.addEntity(m.id, kind: EntityKind.note, name: 'Idea');
    await repo.setCover(env.manuscripts.get(m.id)!, pngBytes());

    await repo.deleteManuscript(env.manuscripts.get(m.id)!);
    expect(env.manuscripts.keys, [other.id]);
    expect(
      env.chapters.values.every((c) => c.manuscriptId == other.id),
      isTrue,
    );
    expect(env.versions.isEmpty, isTrue);
    expect(env.entities.isEmpty, isTrue);
    expect(env.writingLog.isEmpty, isTrue);
    expect(env.files.files, isEmpty);
  });
}
