import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:timezone/timezone.dart' as tz;

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/data/models/job_item.dart';

import 'package:portones_mym/core/constants/app_constants.dart'; // kGold, kRed, etc
import 'package:portones_mym/core/services/notif_service.dart';  // NotifService + gAlarmCache


/* ==========================
   ALARMA TAB (RELOJ SOLO)
   ✅ RELOJ SE MUEVE CON LA HORA REAL (cada 1s)
========================== */

class AlarmTab extends StatefulWidget {
  const AlarmTab({super.key});

  @override
  State<AlarmTab> createState() => _AlarmTabState();
}

class _AlarmTabState extends State<AlarmTab> {
  final List<bool> _days = List<bool>.from(gAlarmCache.daysLtoD);
  bool _enabled = gAlarmCache.enabled;
  TimeOfDay _time = gAlarmCache.time; // ✅ hora de la alarma (configurable)
  final TextEditingController _titleCtrl = TextEditingController(text: gAlarmCache.title);

  Timer? _ticker; // countdown cada 30s
  Timer? _clockTicker; // ✅ reloj real cada 1s

  DateTime _now = DateTime.now(); // ✅ hora real
  double _progress = 0.0;
  String _remainingText = '';
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async => _updateAndSchedule());

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _updateOnly());

    // ✅ repinta reloj cada segundo
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clockTicker?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarmTimeText = NotifService.formatAmPm(_time);
    final liveTime = TimeOfDay.fromDateTime(_now); // ✅ hora real para el reloj

    return Scaffold(
      appBar: AppBar(title: const Text('Alarma')),
      body: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _titleCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Nombre (ej: Trabajos del día)',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) async => _updateAndSchedule(),
            ),
          ),
          const SizedBox(height: 12),
          _DaysRow(
            selected: _days,
            gold: kGold,
            red: kRed,
            onToggle: (i) async {
              setState(() => _days[i] = !_days[i]);
              await _updateAndSchedule();
            },
          ),
          const SizedBox(height: 10),
          Text(
            _remainingText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _enabled ? kGold : Colors.white38,
            ),
          ),
          const SizedBox(height: 10),

          // ✅ Reloj (solo) - se mueve con hora REAL
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: CustomPaint(
                    painter: _AnalogClockPainter(
                      time: liveTime, // ✅ ahora dibuja la hora real
                      enabled: _enabled,
                      gold: kGold,
                      red: kRed,
                      progress: _enabled ? _progress : 0.0,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Text(
                    'ALARMA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _enabled ? kGold : Colors.white38,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _enabled
                        ? () async {
                      final picked = await _showCupertinoTimeWheelAmPm(context, initial: _time);
                      if (picked != null) {
                        setState(() => _time = picked);
                        await _updateAndSchedule();
                      }
                    }
                        : null,
                    child: Text(
                      alarmTimeText,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _enabled ? kRed : Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _enabled,
                    onChanged: (v) async {
                      setState(() => _enabled = v);
                      await _updateAndSchedule();
                    },
                    activeColor: kGold,
                    activeTrackColor: kRed.withOpacity(0.6),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAndSchedule() async {
    _recalcBase();
    _updateOnly();

    final title = _titleCtrl.text.trim().isEmpty ? 'Trabajos del día' : _titleCtrl.text.trim();
    await NotifService.instance.scheduleWeekly(
      title: title,
      daysLtoD: _days,
      time: _time,
      enabled: _enabled,
    );
  }

  void _updateOnly() {
    if (!_enabled) {
      setState(() {
        _remainingText = 'Alarma desactivada';
        _progress = 0.0;
      });
      return;
    }

    final next = _nextOccurrence();
    if (next == null) {
      setState(() {
        _remainingText = 'Seleccioná al menos 1 día';
        _progress = 0.0;
      });
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final diff = next.difference(now);

    if (diff.isNegative) {
      setState(() {
        _remainingText = 'Ahora';
        _progress = 1.0;
      });
      return;
    }

    final total = (_totalSeconds <= 0) ? diff.inSeconds : _totalSeconds;
    final remaining = diff.inSeconds.clamp(0, total);

    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    setState(() {
      _remainingText = 'Faltan ${h}h ${m}m';
      _progress = (1.0 - (remaining / total)).clamp(0.0, 1.0);
    });
  }

  void _recalcBase() {
    final next = _nextOccurrence();
    if (next == null) {
      _totalSeconds = 0;
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final diff = next.difference(now);
    _totalSeconds = diff.inSeconds <= 0 ? 0 : diff.inSeconds;
  }

  tz.TZDateTime? _nextOccurrence() {
    if (_days.every((d) => d == false)) return null;

    tz.TZDateTime? best;
    for (int i = 0; i < 7; i++) {
      if (!_days[i]) continue;
      final cand = NotifService.instance.nextDateForWeekdayAndTime(
        weekdayMon1: i + 1,
        time: _time,
      );
      if (best == null || cand.isBefore(best)) best = cand;
    }
    return best;
  }

  Future<TimeOfDay?> _showCupertinoTimeWheelAmPm(BuildContext context, {required TimeOfDay initial}) async {
    int initHour24 = initial.hour;
    int initMinute = initial.minute;

    bool initIsPm = initHour24 >= 12;
    int initHour12 = initHour24 % 12;
    if (initHour12 == 0) initHour12 = 12;

    int selHour12 = initHour12;
    int selMin = initMinute;
    int selPeriod = initIsPm ? 1 : 0;

    final hourController = FixedExtentScrollController(initialItem: selHour12 - 1);
    final minController = FixedExtentScrollController(initialItem: selMin);
    final periodController = FixedExtentScrollController(initialItem: selPeriod);

    return showDialog<TimeOfDay>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
                    const Spacer(),
                    const Icon(Icons.alarm, color: Colors.white70),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final isPm = (selPeriod == 1);
                        int hour24 = selHour12 % 12;
                        if (isPm) hour24 += 12;
                        Navigator.pop(ctx, TimeOfDay(hour: hour24, minute: selMin));
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: hourController,
                        itemExtent: 48,
                        magnification: 1.12,
                        useMagnifier: true,
                        onSelectedItemChanged: (i) => selHour12 = i + 1,
                        children: List.generate(12, (i) {
                          final h = i + 1;
                          return Center(
                            child: Text(h.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 24, color: Colors.white)),
                          );
                        }),
                      ),
                    ),
                    Container(width: 1, color: Colors.white12),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: minController,
                        itemExtent: 48,
                        magnification: 1.12,
                        useMagnifier: true,
                        onSelectedItemChanged: (i) => selMin = i,
                        children: List.generate(60, (i) {
                          return Center(
                            child: Text(i.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 24, color: Colors.white)),
                          );
                        }),
                      ),
                    ),
                    Container(width: 1, color: Colors.white12),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: periodController,
                        itemExtent: 48,
                        magnification: 1.12,
                        useMagnifier: true,
                        onSelectedItemChanged: (i) => selPeriod = i,
                        children: const [
                          Center(child: Text('AM', style: TextStyle(fontSize: 24, color: Colors.white))),
                          Center(child: Text('PM', style: TextStyle(fontSize: 24, color: Colors.white))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}


class _DaysRow extends StatelessWidget {
  const _DaysRow({required this.selected, required this.onToggle, required this.gold, required this.red});

  final List<bool> selected;
  final Future<void> Function(int) onToggle;
  final Color gold;
  final Color red;

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final isOn = selected[i];
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onToggle(i),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? red.withOpacity(0.95) : Colors.white10,
                border: Border.all(color: isOn ? gold : Colors.white12, width: isOn ? 1.4 : 1),
              ),
              child: Text(
                labels[i],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isOn ? Colors.black : Colors.white70),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* ==========================
   RELOJ ANALÓGICO (ROJO + DORADO) - SOLO RELOJ
========================== */

class _AnalogClockPainter extends CustomPainter {
  _AnalogClockPainter({
    required this.time,
    required this.enabled,
    required this.gold,
    required this.red,
    required this.progress,
  });

  final TimeOfDay time;
  final bool enabled;
  final Color gold;
  final Color red;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.44;

    // Fondo
    canvas.drawCircle(center, r, Paint()..color = Colors.black);

    // Borde base
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round
      ..color = Colors.white24;
    canvas.drawCircle(center, r, base);

    // Aro rojo/dorado
    if (enabled) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [red, gold, red],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi, false, arc);
    }

    // Ticks
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = enabled ? gold.withOpacity(0.9) : Colors.white38;

    for (int i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      final angle = (-math.pi / 2) + (i * 2 * math.pi / 60);
      final len = isHour ? r * 0.10 : r * 0.05;
      final p1 = Offset(
        center.dx + (r - r * 0.16) * math.cos(angle),
        center.dy + (r - r * 0.16) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (r - r * 0.16 - len) * math.cos(angle),
        center.dy + (r - r * 0.16 - len) * math.sin(angle),
      );
      tickPaint.strokeWidth = isHour ? 3.0 : 1.6;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Números 12/3/6/9 (✅ usando ui.TextDirection)
    void drawNum(String s, double ang) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: r * 0.16,
            fontWeight: FontWeight.w800,
            color: enabled ? gold : Colors.white38,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final dist = r * 0.62;
      final pos = Offset(
        center.dx + dist * math.cos(ang) - tp.width / 2,
        center.dy + dist * math.sin(ang) - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }

    drawNum('12', -math.pi / 2);
    drawNum('3', 0);
    drawNum('6', math.pi / 2);
    drawNum('9', math.pi);

    // Manecillas (usa "time")
    final hour = time.hour % 12;
    final minute = time.minute;

    final hourAngle = (-math.pi / 2) + ((hour + minute / 60) * 2 * math.pi / 12);
    final minAngle = (-math.pi / 2) + (minute * 2 * math.pi / 60);

    final hourHand = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.07
      ..color = enabled ? gold : Colors.white38;

    final minHand = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.055
      ..color = enabled ? gold : Colors.white38;

    Offset handEnd(double ang, double length) => Offset(
      center.dx + length * math.cos(ang),
      center.dy + length * math.sin(ang),
    );

    canvas.drawLine(center, handEnd(hourAngle, r * 0.38), hourHand);
    canvas.drawLine(center, handEnd(minAngle, r * 0.55), minHand);

    // Centro
    canvas.drawCircle(center, r * 0.08, Paint()..color = enabled ? red : Colors.white24);
    canvas.drawCircle(center, r * 0.045, Paint()..color = enabled ? gold : Colors.white38);

    // Punto arriba
    final topDot = Offset(
      center.dx + r * math.cos(-math.pi / 2),
      center.dy + r * math.sin(-math.pi / 2),
    );
    canvas.drawCircle(topDot, r * 0.06, Paint()..color = enabled ? gold : Colors.white24);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter old) {
    return old.time != time || old.enabled != enabled || old.progress != progress;
  }
}

String buildDailySummaryText(List<JobItem> jobs) {
  if (jobs.isEmpty) return 'Hoy no hay trabajos programados.';

  final pendientes = jobs.where((j) => !j.isDone).toList();
  final hechos = jobs.where((j) => j.isDone).toList();

  pendientes.sort((a, b) => (a.timeMinutes ?? 99999).compareTo(b.timeMinutes ?? 99999));

  final lines = <String>[];
  lines.add('Pendientes: ${pendientes.length} • Listos: ${hechos.length}');
  lines.add('');

  for (final j in pendientes.take(10)) {
    final hora = (j.timeOfDay == null) ? '' : '${NotifService.formatAmPm(j.timeOfDay!)} • ';
    final loc = (j.locationSnapshot ?? '').trim();
    final cli = (j.clientNameSnapshot ?? '').trim();
    final extra = loc.isNotEmpty ? loc : (cli.isNotEmpty ? cli : '');
    lines.add('• $hora${j.titulo}${extra.isEmpty ? '' : ' — $extra'}');
  }

  if (pendientes.length > 10) {
    lines.add('… y ${pendientes.length - 10} más');
  }

  return lines.join('\n');
}

/* ==========================
   PANTALLA FULL (ALARM RING)
========================== */

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  Timer? _blink;
  bool _pulse = false;

  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _blink = Timer.periodic(
      const Duration(milliseconds: 450),
          (_) => setState(() => _pulse = !_pulse),
    );

    _startAlarmSound();
  }

  Future<void> _startAlarmSound() async {
    try {
      await _player.setLoopMode(LoopMode.one);
      await _player.setAsset('assets/alarm_loud.mp3');
      await _player.setVolume(1.0);
      await _player.play();
    } catch (e) {
      debugPrint('Error reproduciendo alarma: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _blink?.cancel();
    _stopAlarmSound();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = gAlarmCache.title;
    final timeText = NotifService.formatAmPm(gAlarmCache.time);

    // ✅ Trabajos de HOY (Hive vía JobsRepository)
    final jobsRepo = ProviderScope.containerOf(context).read(jobsRepoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final jobsToday = jobsRepo.getForDay(today);
    final summary = buildDailySummaryText(jobsToday);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),

              // ✅ Título arriba (como ya lo tenías)
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),

              const SizedBox(height: 12),

              // ✅ Hora (mantengo tu estilo del círculo, pero más arriba y sin ocupar todo el espacio)
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                    border: Border.all(color: _pulse ? kGold : kRed, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: (_pulse ? kGold : kRed).withOpacity(0.25),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        color: _pulse ? kGold : kRed,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Panel resumen (Diseño 2)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen de hoy',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            summary,
                            style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Botones (idénticos a los tuyos)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
                      onPressed: () async {
                        await _stopAlarmSound();
                        await NotifService.instance.scheduleSnooze10Min();
                        if (mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.snooze),
                      label: const Text('Posponer 10 min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                      onPressed: () async {
                        await _stopAlarmSound();
                        await NotifService.instance.dismissAllAlarmUIs();
                        if (mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.alarm_off),
                      label: const Text('Desactivar'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text(
                'Si no querés que se repita hoy, tocá “Desactivar”.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

