import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:littera/app/app.dart';
import 'package:littera/data/hive/hive_setup.dart';
import 'package:littera/data/models/app_settings.dart';
import 'package:littera/data/repositories/settings_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('littera_test');
    await initHive(path: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  /// Box en memoria: los widget tests usan un reloj simulado y la E/S de disco
  /// de Hive no termina dentro de él.
  Future<Box<AppSettings>> memoryBox() => Hive.openBox<AppSettings>(
    'settings_mem_${DateTime.now().microsecondsSinceEpoch}',
    bytes: Uint8List(0),
  );

  Widget app(Box<AppSettings> box) => ProviderScope(
    overrides: [settingsBoxProvider.overrideWithValue(box)],
    child: const LitteraApp(),
  );

  testWidgets('muestra la biblioteca y navega a Ajustes', (tester) async {
    final box = (await tester.runAsync(memoryBox))!;
    await tester.pumpWidget(app(box));
    await tester.pumpAndSettle();

    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Apariencia'), findsOneWidget);
  });

  testWidgets('elegir Sepia cambia el tema', (tester) async {
    final box = (await tester.runAsync(memoryBox))!;
    await tester.pumpWidget(app(box));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sepia'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.surface, const Color(0xFFF2E8D2));
    expect(materialApp.themeMode, ThemeMode.light);
  });

  test('el tema elegido se guarda en disco y se recupera', () async {
    final container = ProviderContainer();
    await container
        .read(settingsProvider.notifier)
        .setThemePreference(AppThemePreference.dark);
    container.dispose();

    // Cerrar y reabrir la box simula reiniciar la app.
    await Hive.box<AppSettings>(HiveBoxes.settings).close();
    await Hive.openBox<AppSettings>(HiveBoxes.settings);

    final reopened = ProviderContainer();
    expect(
      reopened.read(settingsProvider).themePreference,
      AppThemePreference.dark,
    );
    reopened.dispose();
  });

  test('registra la versión de esquema', () {
    expect(
      Hive.box<dynamic>(HiveBoxes.meta).get(HiveKeys.schemaVersion),
      currentSchemaVersion,
    );
  });
}
