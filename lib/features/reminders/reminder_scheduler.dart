import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_messages.dart';

/// Programa las notificaciones de lectura (todo en el dispositivo).
abstract class ReminderScheduler {
  /// `false` en plataformas sin notificaciones programadas (Web).
  bool get isSupported;

  /// Toques en notificaciones: id del libro que hay que abrir.
  Stream<String> get openBookRequests;

  Future<void> init();

  /// Pide permiso para notificar. Devuelve si se concedió.
  Future<bool> requestPermission();

  Future<void> scheduleDaily(int hour, int minute, ReminderMessage message);
  Future<void> cancelDaily();
  Future<void> scheduleNudge(DateTime when, ReminderMessage message);
  Future<void> cancelNudge();
}

/// Sin notificaciones (Web y tests).
class NoopReminderScheduler implements ReminderScheduler {
  @override
  bool get isSupported => false;
  @override
  Stream<String> get openBookRequests => const Stream.empty();
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> scheduleDaily(int hour, int minute, ReminderMessage m) async {}
  @override
  Future<void> cancelDaily() async {}
  @override
  Future<void> scheduleNudge(DateTime when, ReminderMessage m) async {}
  @override
  Future<void> cancelNudge() async {}
}

/// Implementación con flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? _launchBookId;

  static const _dailyId = 1;
  static const _nudgeId = 2;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lectura',
      'Recordatorios de lectura',
      channelDescription: 'Tu rato de lectura y libros que dejaste a medias',
      icon: 'ic_stat_littera',
      color: Color(0xFFC9A45C),
    ),
  );

  @override
  bool get isSupported => !kIsWeb;

  @override
  Stream<String> get openBookRequests async* {
    // Si la app se abrió desde una notificación, primero ese libro.
    final launch = _launchBookId;
    if (launch != null) {
      _launchBookId = null;
      yield launch;
    }
    yield* _taps.stream;
  }

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('Zona horaria desconocida, se usa UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_littera'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = ReminderMessage.bookIdFromPayload(response.payload);
        if (id != null) _taps.add(id);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchBookId = ReminderMessage.bookIdFromPayload(
        launch!.notificationResponse?.payload,
      );
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  /// Próxima vez que el reloj marque [hour]:[minute].
  tz.TZDateTime _next(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }

  @override
  Future<void> scheduleDaily(int hour, int minute, ReminderMessage m) =>
      _plugin.zonedSchedule(
        id: _dailyId,
        scheduledDate: _next(hour, minute),
        notificationDetails: _details,
        // No exacto: sin permiso de alarmas exactas; Android puede
        // retrasarlo unos minutos para ahorrar batería.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: m.title,
        body: m.body,
        payload: m.payload,
        matchDateTimeComponents: DateTimeComponents.time,
      );

  @override
  Future<void> cancelDaily() => _plugin.cancel(id: _dailyId);

  @override
  Future<void> scheduleNudge(DateTime when, ReminderMessage m) =>
      _plugin.zonedSchedule(
        id: _nudgeId,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: m.title,
        body: m.body,
        payload: m.payload,
      );

  @override
  Future<void> cancelNudge() => _plugin.cancel(id: _nudgeId);
}

/// Se sobrescribe en `main` (real en Android, nulo en Web).
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => NoopReminderScheduler(),
);
