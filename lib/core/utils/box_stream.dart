import 'dart:async';

import 'package:hive_ce/hive_ce.dart';

/// Emite `read()` al empezar y cada vez que cambia la box.
///
/// Se suscribe a los cambios ANTES de emitir el valor inicial. Hacerlo al
/// revés (emitir y luego escuchar, como con `async*` + `yield*`) deja un
/// hueco en el que un cambio se pierde y la pantalla no se actualiza.
Stream<T> watchBox<T>(Box<dynamic> box, T Function() read) {
  late final StreamController<T> controller;
  StreamSubscription<BoxEvent>? subscription;
  controller = StreamController<T>(
    onListen: () {
      subscription = box.watch().listen((_) => controller.add(read()));
      controller.add(read());
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}
