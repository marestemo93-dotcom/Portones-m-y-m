import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/utils/formatters.dart';

class IngresosChartScreen extends ConsumerStatefulWidget {
  const IngresosChartScreen({super.key});

  @override
  ConsumerState<IngresosChartScreen> createState() => _IngresosChartScreenState();
}

class _IngresosChartScreenState extends ConsumerState<IngresosChartScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final jobsRepo = ref.watch(jobsRepoProvider);
    final events = jobsRepo.getAllEvents();

    // ====== Helpers de fecha (sin hora) ======
    DateTime onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    DateTime weekStartMon(DateTime d) {
      // Monday = 1 ... Sunday = 7
      final od = onlyDay(d);
      return od.subtract(Duration(days: od.weekday - 1));
    }

    // ====== Acumuladores ======
    final ingresosPorMes = <int, double>{for (int m = 1; m <= 12; m++) m: 0.0};

    final now = DateTime.now();
    final today = onlyDay(now);

    final startThisWeek = weekStartMon(today);
    final startNextWeek = startThisWeek.add(const Duration(days: 7));

    final startPrevWeek = startThisWeek.subtract(const Duration(days: 7));
    final startThisMonth = DateTime(today.year, today.month, 1);
    final startNextMonth = DateTime(today.year, today.month + 1, 1);
    final startPrevMonth = DateTime(today.year, today.month - 1, 1);

    double ingresosHoy = 0.0;
    double ingresosSemana = 0.0;
    double ingresosSemanaPrev = 0.0;
    double ingresosMes = 0.0;
    double ingresosMesPrev = 0.0;

    // ====== Recorremos todos los jobs ======
    for (final entry in events.entries) {
      for (final job in entry.value) {
        if (!job.isDone) continue;
        final monto = job.montoCrc;
        if (monto == null) continue;

        final d = onlyDay(job.fecha);

        // 1) Chart anual por mes
        if (job.fecha.year == _year) {
          ingresosPorMes[job.fecha.month] =
              (ingresosPorMes[job.fecha.month] ?? 0) + monto;
        }

        // 2) KPIs (hoy/semana/mes)
        if (sameDay(d, today)) ingresosHoy += monto;

        if (!d.isBefore(startThisWeek) && d.isBefore(startNextWeek)) {
          ingresosSemana += monto;
        } else if (!d.isBefore(startPrevWeek) && d.isBefore(startThisWeek)) {
          ingresosSemanaPrev += monto;
        }

        if (!d.isBefore(startThisMonth) && d.isBefore(startNextMonth)) {
          ingresosMes += monto;
        } else if (!d.isBefore(startPrevMonth) && d.isBefore(startThisMonth)) {
          ingresosMesPrev += monto;
        }
      }
    }

    // ====== Datos para gráfico ======
    final spots = <FlSpot>[
      for (int m = 1; m <= 12; m++)
        FlSpot(m.toDouble(), (ingresosPorMes[m] ?? 0.0)),
    ];

    final maxY = spots.map((s) => s.y).fold<double>(0.0, (p, v) => v > p ? v : p);
    final double chartMaxY = (maxY <= 0) ? 100000.0 : (maxY * 1.20);

    final totalYear = ingresosPorMes.values.fold<double>(0.0, (p, v) => p + v);

    // ====== Comparaciones / % ======
    double pct(double current, double prev) {
      if (prev <= 0) return current > 0 ? 100.0 : 0.0;
      return ((current - prev) / prev) * 100.0;
    }

    final pctSemana = pct(ingresosSemana, ingresosSemanaPrev);
    final pctMes = pct(ingresosMes, ingresosMesPrev);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        elevation: 0,
        title: const Text('Ingresos', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _YearHeader(
              year: _year,
              onPrev: () => setState(() => _year--),
              onNext: () => setState(() => _year++),
              total: totalYear,
            ),
            const SizedBox(height: 12),

            _KpiRow(
              ingresosHoy: ingresosHoy,
              ingresosSemana: ingresosSemana,
              ingresosMes: ingresosMes,
              ingresosSemanaPrev: ingresosSemanaPrev,
              ingresosMesPrev: ingresosMesPrev,
              pctSemana: pctSemana,
              pctMes: pctMes,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24,
                      spreadRadius: 0,
                      color: Colors.black.withValues(alpha:0.35),
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingresos por mes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solo trabajos marcados como Listo con monto.',
                      style: TextStyle(color: Colors.white.withValues(alpha:0.65)),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: LineChart(
                        LineChartData(
                          minX: 1,
                          maxX: 12,
                          minY: 0,
                          maxY: chartMaxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: chartMaxY / 4.0,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: Colors.white.withValues(alpha:0.06),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 64,
                                interval: chartMaxY / 4.0,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      formatCrcCompact(value),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha:0.65),
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final m = value.toInt();
                                  const names = [
                                    '',
                                    'ENE',
                                    'FEB',
                                    'MAR',
                                    'ABR',
                                    'MAY',
                                    'JUN',
                                    'JUL',
                                    'AGO',
                                    'SEP',
                                    'OCT',
                                    'NOV',
                                    'DIC'
                                  ];
                                  if (m < 1 || m > 12) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      names[m],
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha:0.75),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 12,
                              tooltipPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              tooltipBgColor: const Color(0xFF0B0F14),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((s) {
                                  final m = s.x.toInt();
                                  final mes =
                                  DateFormat.MMMM('es').format(DateTime(_year, m, 1));
                                  final monto = s.y;
                                  return LineTooltipItem(
                                    '${_cap(mes)}\n₡${monto.toStringAsFixed(0)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              barWidth: 3,
                              color: const Color(0xFF2DD4BF),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                      radius: 4.2,
                                      color: const Color(0xFF2DD4BF),
                                      strokeWidth: 2,
                                      strokeColor: const Color(0xFF0B0F14),
                                    ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF2DD4BF).withValues(alpha:0.30),
                                    const Color(0xFF2DD4BF).withValues(alpha:0.02),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const _LegendDot(color: Color(0xFF2DD4BF)),
                        const SizedBox(width: 8),
                        Text(
                          'Ingresos (₡) por mes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// --- El resto de tus widgets quedan EXACTAMENTE igual ---

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.ingresosHoy,
    required this.ingresosSemana,
    required this.ingresosMes,
    required this.ingresosSemanaPrev,
    required this.ingresosMesPrev,
    required this.pctSemana,
    required this.pctMes,
  });

  final double ingresosHoy;
  final double ingresosSemana;
  final double ingresosMes;

  final double ingresosSemanaPrev;
  final double ingresosMesPrev;

  final double pctSemana;
  final double pctMes;

  Color _deltaColor(double pct) {
    if (pct > 0) return const Color(0xFF22C55E);
    if (pct < 0) return const Color(0xFFEF4444);
    return Colors.white.withValues(alpha:0.65);
  }

  String _deltaText(double pct) {
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: _KpiCard(
              title: 'Hoy',
              value: formatCrc(ingresosHoy),
              subtitle: 'Ingresos',
              icon: Icons.today,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 210,
            child: _KpiCard(
              title: 'Semana',
              value: formatCrc(ingresosSemana),
              subtitle: 'vs ant. ${formatCrc(ingresosSemanaPrev)}',
              icon: Icons.calendar_view_week,
              trailing: _Badge(
                text: _deltaText(pctSemana),
                color: _deltaColor(pctSemana),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 210,
            child: _KpiCard(
              title: 'Mes',
              value: formatCrc(ingresosMes),
              subtitle: 'vs ant. ${formatCrc(ingresosMesPrev)}',
              icon: Icons.calendar_month,
              trailing: _Badge(
                text: _deltaText(pctMes),
                color: _deltaColor(pctMes),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha:0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha:0.8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.75),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha:0.60), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha:0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha:0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.year,
    required this.onPrev,
    required this.onNext,
    required this.total,
  });

  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha:0.06)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white.withValues(alpha:0.85),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Año', style: TextStyle(color: Colors.white.withValues(alpha:0.65))),
                const SizedBox(height: 2),
                Text(
                  year.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white.withValues(alpha:0.85),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total año', style: TextStyle(color: Colors.white.withValues(alpha:0.65))),
              const SizedBox(height: 2),
              Text(
                formatCrc(total),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: Color(0xFF2DD4BF), shape: BoxShape.circle),
    );
  }
}