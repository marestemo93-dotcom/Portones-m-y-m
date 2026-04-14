import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/navigation/nav_key.dart';


/// Cache simple para la alarma semanal (UI + snooze)
class AlarmStateCache {
  final String title;
  final TimeOfDay time;
  final List<bool> daysLtoD; // L..D
  final bool enabled;

  AlarmStateCache({
    required this.title,
    required this.time,
    required this.daysLtoD,
    required this.enabled,
  });

  factory AlarmStateCache.initial() => AlarmStateCache(
    title: 'Trabajos del día',
    time: const TimeOfDay(hour: 6, minute: 0),
    daysLtoD: [true, true, true, true, true, true, true],
    enabled: true,
  );
}

/// ✅ Global (lo usás en AlarmTab y AlarmRingScreen)
AlarmStateCache gAlarmCache = AlarmStateCache.initial();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Android abre Activity cuando es fullScreenIntent; aquí no navegamos.
}

class NotifService {
  NotifService._();
  static final NotifService instance = NotifService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();

    // ✅ fijo Costa Rica para evitar dependencias extra
    try {
      tz.setLocalLocation(tz.getLocation('America/Costa_Rica'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotifResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const channel = AndroidNotificationChannel(
      kAlarmChannelId,
      kAlarmChannelName,
      description: kAlarmChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    // Android 13+ permiso notificaciones
    await android?.requestNotificationsPermission();

    // ✅ Exact alarms (Samsung lo pide)
    await android?.requestExactAlarmsPermission();
  }

  void _onNotifResponse(NotificationResponse response) async {
    if (response.actionId == kActionSnooze10) {
      await scheduleSnooze10Min();
      return;
    }
    if (response.actionId == kActionDismiss) {
      await dismissAllAlarmUIs();
      return;
    }

    if (response.payload == kPayloadAlarm) {
      _openFullScreenAlarm();
    }
  }

  void _openFullScreenAlarm() {
    final ctx = navKey.currentContext;
    if (ctx == null) return;

    // ✅ Importante: AlarmRingScreen sigue en main.dart por ahora,
    // así que lo abrimos por nombre de ruta NO.
    // Entonces, por ahora, dejamos que lo abra el código donde está la pantalla.
    //
    // Como tu app actual lo abre con MaterialPageRoute a AlarmRingScreen,
    // esa clase debe estar visible desde el contexto actual.
    //
    // Si te da error aquí cuando borremos del main, lo resolvemos moviendo AlarmRingScreen a feature/alarm.
  }

  /// ⚠️ En tu código original, _openFullScreenAlarm navegaba directo a AlarmRingScreen.
  /// Como esa pantalla todavía está en main.dart, NO la referenciamos aquí
  /// para evitar dependencias circulares.
  ///
  /// ✅ Solución rápida: dejar navegación en main.dart (en AlarmTab o en init del plugin)
  /// ✅ Solución pro: mover AlarmRingScreen a features/alarm y luego sí importarla aquí.
  ///
  /// Para no romper nada ahora, manejamos el "tap" desde donde esté la pantalla.
  /// Aun así, el schedule/cancel/snooze funciona normal.

  Future<void> dismissAllAlarmUIs() async {
    await _plugin.cancel(kSnoozeNotifId);
    final ctx = navKey.currentContext;
    if (ctx != null && Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).popUntil((r) => r.isFirst);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> scheduleWeekly({
    required String title,
    required List<bool> daysLtoD,
    required TimeOfDay time,
    required bool enabled,
  }) async {
    gAlarmCache = AlarmStateCache(
      title: title,
      time: time,
      daysLtoD: List<bool>.from(daysLtoD),
      enabled: enabled,
    );

    await cancelAll();
    if (!enabled) return;

    for (int i = 0; i < 7; i++) {
      if (!daysLtoD[i]) continue;

      final next = nextDateForWeekdayAndTime(weekdayMon1: i + 1, time: time);

      await _plugin.zonedSchedule(
        100 + i,
        title,
        'Alarma: ${formatAmPm(time)}',
        next,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kAlarmChannelId,
            kAlarmChannelName,
            channelDescription: kAlarmChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            vibrationPattern: Int64List.fromList([0, 1200, 250, 1200, 250, 1200]),
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(kActionSnooze10, 'Posponer 10 min', showsUserInterface: true),
              AndroidNotificationAction(kActionDismiss, 'Desactivar', showsUserInterface: true),
            ],
          ),
        ),
        payload: kPayloadAlarm,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> scheduleSnooze10Min() async {
    if (!gAlarmCache.enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final when = now.add(const Duration(minutes: 10));

    await _plugin.zonedSchedule(
      kSnoozeNotifId,
      gAlarmCache.title,
      'Pospuesto 10 min • ${formatAmPm(gAlarmCache.time)}',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kAlarmChannelId,
          kAlarmChannelName,
          channelDescription: kAlarmChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          vibrationPattern: Int64List.fromList([0, 1400, 250, 1400, 250, 1400]),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(kActionSnooze10, 'Posponer 10 min', showsUserInterface: true),
            AndroidNotificationAction(kActionDismiss, 'Desactivar', showsUserInterface: true),
          ],
        ),
      ),
      payload: kPayloadAlarm,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime nextDateForWeekdayAndTime({
    required int weekdayMon1, // Mon=1..Sun=7
    required TimeOfDay time,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    final nowW = now.weekday;
    int diff = weekdayMon1 - nowW;
    if (diff < 0) diff += 7;
    candidate = candidate.add(Duration(days: diff));

    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static String formatAmPm(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final isPm = h >= 12;
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    return '${hour12.toString().padLeft(2, '0')}:$m ${isPm ? "PM" : "AM"}';
  }
}