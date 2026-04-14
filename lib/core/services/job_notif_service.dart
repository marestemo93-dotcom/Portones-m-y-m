import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class JobNotifService {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  // ✅ 8 horas después
  static const int _postHours = 8;

  // Offsets para IDs por trabajo
  static const int _offMinus60 = 1;
  static const int _offMinus30 = 2;
  static const int _offExact = 3;
  static const int _offHourlyStart = 10; // 10..17

  static Future<void> init() async {
    if (_inited) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _p.initialize(settings);

    // Android 13+ permission
    await _p
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _inited = true;
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'jobs_channel',
      'Trabajos',
      channelDescription: 'Recordatorios por trabajo',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  // ---------- IDs determinísticos por trabajo ----------
  static int _hashJob(String jobId) {
    // FNV-1a 32-bit
    const int fnvPrime = 16777619;
    int hash = 2166136261;
    for (final c in jobId.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  // baseId deja espacio para offsets sin chocar
  static int _baseId(String jobId) => (_hashJob(jobId) % 20000000) * 100;
  static int _id(String jobId, int offset) => _baseId(jobId) + offset;

  static Future<void> cancelAllForJob(String jobId) async {
    await init();

    final ids = <int>[
      _id(jobId, _offMinus60),
      _id(jobId, _offMinus30),
      _id(jobId, _offExact),
      for (int i = 0; i < _postHours; i++) _id(jobId, _offHourlyStart + i),
    ];

    for (final nid in ids) {
      await _p.cancel(nid);
    }
  }

  static Future<void> _scheduleAt({
    required int notifId,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    // No programar en el pasado
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _p.zonedSchedule(
      notifId,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// ✅ Programa:
  /// - 1h antes
  /// - 30 min antes
  /// - a la hora
  /// - cada hora por 8 horas después
  ///
  /// Llamar SOLO si timeMinutes != null
  static Future<void> scheduleCascade({
    required String jobId,
    required String titulo,
    required DateTime day, // fecha del trabajo
    required int timeMinutes,
    String? body,
  }) async {
    await init();

    final hour = timeMinutes ~/ 60;
    final minute = timeMinutes % 60;

    final due = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    );

    final msg = (body == null || body.trim().isEmpty) ? 'Trabajo pendiente' : body.trim();

    // Limpia lo anterior
    await cancelAllForJob(jobId);

    // -60 min
    await _scheduleAt(
      notifId: _id(jobId, _offMinus60),
      title: 'En 1 hora: $titulo',
      body: msg,
      when: due.subtract(const Duration(hours: 1)),
    );

    // -30 min
    await _scheduleAt(
      notifId: _id(jobId, _offMinus30),
      title: 'En 30 min: $titulo',
      body: msg,
      when: due.subtract(const Duration(minutes: 30)),
    );

    // exacto
    await _scheduleAt(
      notifId: _id(jobId, _offExact),
      title: 'Ahora: $titulo',
      body: msg,
      when: due,
    );

    // cada hora por 8 horas
    for (int i = 0; i < _postHours; i++) {
      await _scheduleAt(
        notifId: _id(jobId, _offHourlyStart + i),
        title: 'Pendiente: $titulo',
        body: msg,
        when: due.add(Duration(hours: i + 1)),
      );
    }
  }
}
