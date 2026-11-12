import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../hive/hive_setup.dart';
import '../models/app_settings.dart';

/// Box de ajustes (ya abierta en `initHive`). Se puede sobrescribir en tests.
final settingsBoxProvider = Provider<Box<AppSettings>>(
  (ref) => Hive.box<AppSettings>(HiveBoxes.settings),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  Box<AppSettings> get _box => ref.read(settingsBoxProvider);

  @override
  AppSettings build() =>
      ref.read(settingsBoxProvider).get(HiveKeys.appSettings) ??
      const AppSettings();

  Future<void> setThemePreference(AppThemePreference value) =>
      _save(state.copyWith(themePreference: value));

  Future<void> setLibraryGridView(bool value) =>
      _save(state.copyWith(libraryGridView: value));

  Future<void> setLibrarySort(LibrarySort value) =>
      _save(state.copyWith(librarySort: value));

  Future<void> setReaderTheme(ReaderTheme value) =>
      _save(state.copyWith(readerTheme: value));

  Future<void> setReaderFontSize(double value) => _save(
    state.copyWith(
      readerFontSize: value.clamp(
        ReaderLimits.minFontSize,
        ReaderLimits.maxFontSize,
      ),
    ),
  );

  Future<void> setReaderLineHeight(double value) => _save(
    state.copyWith(
      readerLineHeight: value.clamp(
        ReaderLimits.minLineHeight,
        ReaderLimits.maxLineHeight,
      ),
    ),
  );

  Future<void> setReaderJustify(bool value) =>
      _save(state.copyWith(readerJustify: value));

  Future<void> setReaderSerif(bool value) =>
      _save(state.copyWith(readerSerif: value));

  Future<void> setReminder({bool? enabled, int? hour, int? minute}) => _save(
    state.copyWith(
      reminderEnabled: enabled,
      reminderHour: hour?.clamp(0, 23),
      reminderMinute: minute?.clamp(0, 59),
    ),
  );

  Future<void> setNudgesEnabled(bool value) =>
      _save(state.copyWith(nudgesEnabled: value));

  Future<void> completeOnboarding() =>
      _save(state.copyWith(onboardingDone: true));

  Future<void> _save(AppSettings value) async {
    state = value;
    await _box.put(HiveKeys.appSettings, value);
  }
}
