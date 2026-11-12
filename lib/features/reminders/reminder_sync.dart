import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'reminder_messages.dart';
import 'reminder_scheduler.dart';

/// Mantiene los avisos al día: se reprograman al cambiar los ajustes o los
/// libros (así el mensaje habla de lo que estás leyendo ahora).
class ReminderSync {
  ReminderSync(this._ref) {
    _ref.listen<AppSettings>(settingsProvider, (_, _) => _scheduleSoon());
    _ref.listen<AsyncValue<List<Book>>>(
      booksProvider,
      (_, _) => _scheduleSoon(),
    );
    _scheduleSoon();
  }

  final Ref _ref;
  Timer? _timer;

  /// Espera un poco: mientras lees, el progreso se guarda a menudo.
  static const debounce = Duration(seconds: 2);

  void _scheduleSoon() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  Future<void> syncNow({DateTime? now}) async {
    final scheduler = _ref.read(reminderSchedulerProvider);
    if (!scheduler.isSupported) return;
    final settings = _ref.read(settingsProvider);
    final books = _ref.read(booksProvider).value ?? const <Book>[];
    try {
      if (settings.reminderEnabled) {
        await scheduler.scheduleDaily(
          settings.reminderHour,
          settings.reminderMinute,
          dailyReminderMessage(books),
        );
      } else {
        await scheduler.cancelDaily();
      }
      final plan = settings.nudgesEnabled
          ? finishNudge(
              books,
              now: now ?? DateTime.now(),
              hour: settings.reminderHour,
              minute: settings.reminderMinute,
            )
          : null;
      if (plan == null) {
        await scheduler.cancelNudge();
      } else {
        await scheduler.scheduleNudge(plan.when, plan.message);
      }
    } catch (e) {
      debugPrint('No se pudieron programar los recordatorios: $e');
    }
  }

  void dispose() => _timer?.cancel();
}

/// Se observa desde la raíz de la app para que siga activo.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
