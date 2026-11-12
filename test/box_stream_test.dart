import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/core/utils/box_stream.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUpAll(() async => dir = await initTestHive());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'no pierde cambios hechos justo después de empezar a escuchar',
    () async {
      final box = await memoryBox<int>();
      await box.put('previo', 0);
      final events = <List<int>>[];
      final sub = watchBox(box, () => box.values.toList()).listen(events.add);

      // Sin esperar nada: el cambio cae en el instante de la suscripción.
      final write = box.put('nuevo', 1);
      await write;
      await Future<void>.delayed(Duration.zero);

      expect(events.first, contains(0));
      expect(events.last, containsAll([0, 1]));
      await sub.cancel();
    },
  );

  test('deja de escuchar al cancelar', () async {
    final box = await memoryBox<int>();
    final events = <int>[];
    final sub = watchBox(box, () => box.length).listen(events.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await box.put('x', 1);
    await Future<void>.delayed(Duration.zero);
    expect(events, [0]);
  });
}
