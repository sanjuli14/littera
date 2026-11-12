import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../reminders/reminder_messages.dart';
import '../reminders/reminder_scheduler.dart';
import 'app_release.dart';
import 'update_service.dart';

/// Versión instalada (se sobrescribe en `main` con la real del paquete).
final currentVersionProvider = Provider<String>((ref) => AppInfo.appVersion);

/// `null` = sin actualizaciones (Web y tests). Se crea en `main`.
final updateServiceProvider = Provider<UpdateService?>((ref) => null);

class UpdatesState {
  const UpdatesState({
    this.releases = const [],
    this.available,
    this.checking = false,
    this.error,
    this.dismissed = false,
  });

  /// Historial de versiones (de la última consulta).
  final List<AppRelease> releases;

  /// Versión nueva instalable, si la hay.
  final AppRelease? available;
  final bool checking;
  final String? error;

  /// El usuario cerró la tarjeta de esta versión en Inicio.
  final bool dismissed;

  bool get showBanner => available != null && !dismissed;

  UpdatesState copyWith({
    List<AppRelease>? releases,
    AppRelease? available,
    bool clearAvailable = false,
    bool? checking,
    String? error,
    bool clearError = false,
    bool? dismissed,
  }) => UpdatesState(
    releases: releases ?? this.releases,
    available: clearAvailable ? null : (available ?? this.available),
    checking: checking ?? this.checking,
    error: clearError ? null : (error ?? this.error),
    dismissed: dismissed ?? this.dismissed,
  );
}

class UpdatesNotifier extends Notifier<UpdatesState> {
  UpdateService? get _service => ref.read(updateServiceProvider);

  @override
  UpdatesState build() {
    final service = ref.watch(updateServiceProvider);
    if (service == null) return const UpdatesState();
    final cached = service.cachedReleases();
    final available = service.newestUpdate(cached);
    return UpdatesState(
      releases: cached,
      available: available,
      dismissed: available != null && service.isDismissed(available.version),
    );
  }

  /// Al abrir la app: consulta si toca y avisa una vez por versión nueva.
  Future<void> checkOnLaunch({DateTime? now}) async {
    final service = _service;
    if (service == null || !service.shouldCheck(now ?? DateTime.now())) return;
    await refresh(now: now, silent: true);
    final update = state.available;
    if (update != null && await service.markNotified(update.version)) {
      final firstLine = update.notes
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[#\-*\s]+'), '').trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => '');
      await ref
          .read(reminderSchedulerProvider)
          .showNow(
            ReminderMessage(
              'Littera ${update.version} ya está aquí',
              firstLine.isEmpty ? 'Toca para ver las novedades.' : firstLine,
              payload: ReminderMessage.updatePayload,
            ),
          );
    }
  }

  /// Consulta GitHub ahora (botón "Buscar actualizaciones").
  Future<void> refresh({DateTime? now, bool silent = false}) async {
    final service = _service;
    if (service == null) return;
    state = state.copyWith(checking: true, clearError: true);
    try {
      final releases = await service.fetchReleases(now: now);
      final available = service.newestUpdate(releases);
      state = UpdatesState(
        releases: releases,
        available: available,
        dismissed: available != null && service.isDismissed(available.version),
      );
    } on UpdateException catch (e) {
      state = state.copyWith(checking: false, error: silent ? null : e.message);
    } catch (e) {
      debugPrint('Error buscando actualizaciones: $e');
      state = state.copyWith(
        checking: false,
        error: silent ? null : 'No se pudo comprobar.',
      );
    }
  }

  Future<void> dismissBanner() async {
    final update = state.available;
    if (update == null) return;
    await _service?.dismiss(update.version);
    state = state.copyWith(dismissed: true);
  }
}

final updatesProvider = NotifierProvider<UpdatesNotifier, UpdatesState>(
  UpdatesNotifier.new,
);
