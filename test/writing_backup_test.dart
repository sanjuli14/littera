import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/data/models/manuscript.dart';
import 'package:littera/features/backup/backup_service.dart';

import 'helpers.dart';

String delta(String text) => jsonEncode([
  {'insert': '$text\n'},
]);

BackupService service(TestEnv e) => BackupService(
  books: e.books,
  shelves: e.shelves,
  settings: e.settings,
  meta: e.meta,
  files: e.files,
  highlights: e.highlights,
  writing: e.writingRepository,
);

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  late TestEnv phone;
  late String manuscriptId;
  late String chapterId;

  setUp(() async {
    phone = await TestEnv.create();
    final repo = phone.writingRepository;
    final m = await repo.createManuscript('Mi novela');
    manuscriptId = m.id;
    chapterId = repo.chaptersOf(m.id).single.id;
    await repo.saveChapterContent(chapterId, delta('Había una vez un faro'));
    await repo.snapshot(chapterId, manual: true, label: 'Primer borrador');
    await repo.addEntity(m.id, kind: EntityKind.character, name: 'Marina');
    await repo.setCover(phone.manuscripts.get(m.id)!, pngBytes());
  });

  test('las obras van en la copia y se recuperan al reinstalar', () async {
    final bytes = await service(phone).create(includeBookFiles: true);

    final fresh = await TestEnv.create();
    final contents = service(fresh).read(bytes);
    expect(contents.manifest.manuscriptCount, 1);

    final result = await service(fresh).restore(contents, RestoreMode.replace);
    expect(result.manuscriptsAdded, 1);

    final repo = fresh.writingRepository;
    final m = fresh.manuscripts.get(manuscriptId)!;
    expect(m.title, 'Mi novela');
    expect(m.coverRef, isNotNull);
    expect(fresh.files.files.containsKey(m.coverRef), isTrue);
    expect(
      fresh.chapters.get(chapterId)!.content,
      delta('Había una vez un faro'),
    );
    expect(repo.totalWords(manuscriptId), 5);
    expect(repo.versionsOf(chapterId).single.label, 'Primer borrador');
    expect(repo.entitiesOf(manuscriptId).single.name, 'Marina');
    expect(fresh.writingLog.isNotEmpty, isTrue);
  });

  test('una copia de "solo datos" también lleva las obras', () async {
    final bytes = await service(phone).create(includeBookFiles: false);
    final fresh = await TestEnv.create();
    final result = await service(fresh)
        .restore(service(fresh).read(bytes), RestoreMode.merge);
    expect(result.manuscriptsAdded, 1);
    expect(fresh.chapters.get(chapterId), isNotNull);
  });

  test(
    'fusionar: gana lo más reciente y no se pierde el texto local',
    () async {
      final bytes = await service(phone).create(includeBookFiles: false);

      // En la tablet se restauró antes y luego se siguió escribiendo.
      final tablet = await TestEnv.create();
      await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await tablet.writingRepository.saveChapterContent(
        chapterId,
        delta('Texto más nuevo de la tablet'),
      );

      // Restaurar de nuevo la copia (más antigua) no pisa lo nuevo.
      final again = await service(tablet)
          .restore(service(tablet).read(bytes), RestoreMode.merge);
      expect(again.manuscriptsAdded, 0);
      expect(
        tablet.chapters.get(chapterId)!.content,
        delta('Texto más nuevo de la tablet'),
      );

      // Y si la copia es más nueva, se aplica guardando antes lo local.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await phone.writingRepository.saveChapterContent(
        chapterId,
        delta('Versión final del teléfono'),
      );
      final newer = await service(phone).create(includeBookFiles: false);
      final r = await service(tablet)
          .restore(service(tablet).read(newer), RestoreMode.merge);
      expect(r.manuscriptsUpdated, 1);
      expect(
        tablet.chapters.get(chapterId)!.content,
        delta('Versión final del teléfono'),
      );
      expect(
        tablet.writingRepository.versionsOf(chapterId).map((v) => v.content),
        contains(delta('Texto más nuevo de la tablet')),
      );
    },
  );

  test('reemplazar borra las obras que no están en la copia', () async {
    final bytes = await service(phone).create(includeBookFiles: true);
    final extra = await phone.writingRepository.createManuscript('Borrador');
    await service(phone)
        .restore(service(phone).read(bytes), RestoreMode.replace);
    expect(phone.manuscripts.keys, [manuscriptId]);
    expect(
      phone.chapters.values.where((c) => c.manuscriptId == extra.id),
      isEmpty,
    );
  });
}
