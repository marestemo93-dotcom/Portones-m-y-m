import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ingresos_chart_screen.dart';
import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/core/utils/formatters.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/screens/job_detail_screen.dart';
import 'package:portones_mym/core/services/notif_service.dart';
import 'package:local_auth/local_auth.dart';

enum RegFilter { pending, done, all }

class RegistroTab extends ConsumerStatefulWidget {
  const RegistroTab({super.key});

  @override
  ConsumerState<RegistroTab> createState() => _RegistroTabState();
}

class _RegistroTabState extends ConsumerState<RegistroTab> {
  String _q = '';
  RegFilter _filter = RegFilter.pending;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(kJobsBox);

    return ValueListenableBuilder<Box>(
      valueListenable: box.listenable(), // ✅ clave: repinta al cambiar Hive
      builder: (context, _, __) {
        // ✅ Leemos TODO desde Hive (siempre actualizado)
        final all = _getAllJobsFromHive(); // (ya incluye dedupe por id)

        final next = _getNextPendingFromList(all);

        final q = _q.trim().toLowerCase();

        List<JobItem> filtered = all.where((j) {
          if (_filter == RegFilter.pending && j.isDone) return false;
          if (_filter == RegFilter.done && !j.isDone) return false;

          if (q.isEmpty) return true;

          final loc = (j.locationSnapshot ?? '').toLowerCase();
          final cli = (j.clientNameSnapshot ?? '').toLowerCase();
          return j.titulo.toLowerCase().contains(q) || loc.contains(q) || cli.contains(q);
        }).toList();

        // Agrupar por fecha
        final byDay = <DateTime, List<JobItem>>{};
        for (final j in filtered) {
          final d = DateTime(j.fecha.year, j.fecha.month, j.fecha.day);
          byDay.putIfAbsent(d, () => []).add(j);
        }

        final days = byDay.keys.toList()..sort((a, b) => a.compareTo(b));
        for (final d in days) {
          byDay[d]!.sort((a, b) => (a.timeMinutes ?? 99999).compareTo(b.timeMinutes ?? 99999));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Registro'),
            actions: [
              IconButton(
                tooltip: 'Ingresos',
                icon: const Icon(Icons.show_chart),
                onPressed: () async {
                  final auth = LocalAuthentication();

                  try {
                    final isSupported = await auth.isDeviceSupported();
                    final canCheck = await auth.canCheckBiometrics;

                    if (!isSupported && !canCheck) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Este teléfono no soporta huella/PIN biométrico')),
                      );
                      return;
                    }

                    final ok = await auth.authenticate(
                      localizedReason: 'Autenticá para ver Ingresos',
                      options: const AuthenticationOptions(
                        biometricOnly: false, // permite PIN/patrón si no hay huella
                        stickyAuth: true,
                        useErrorDialogs: true,
                      ),
                    );

                    if (!ok) return;
                    if (!context.mounted) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IngresosChartScreen()),
                    );
                  } catch (e) {
                    // 👇 Esto te confirma que SÍ entró al botón y por qué falló
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error biometría: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Próximo pendiente
              if (next != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Card(
                    child: ListTile(
                      title: const Text(
                        'Próximo trabajo pendiente',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${DateFormat.yMMMd(kLocaleEs).format(next.fecha)}'
                            '${next.timeOfDay == null ? '' : ' • ${NotifService.formatAmPm(next.timeOfDay!)}'}'
                            '\n${next.titulo}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final dayOnly = DateTime(next.fecha.year, next.fecha.month, next.fecha.day);

                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => JobDetailScreen(day: dayOnly, job: next)),
                        );

                        if (!mounted) return;
                        setState(() {}); // ok (aunque ya no es obligatorio)
                      },
                    ),
                  ),
                ),

              // Buscar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar trabajo…',
                    filled: true,
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

              // Filtros
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Pendientes'),
                      selected: _filter == RegFilter.pending,
                      onSelected: (_) => setState(() => _filter = RegFilter.pending),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Hechos'),
                      selected: _filter == RegFilter.done,
                      onSelected: (_) => setState(() => _filter = RegFilter.done),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filter == RegFilter.all,
                      onSelected: (_) => setState(() => _filter = RegFilter.all),
                    ),
                  ],
                ),
              ),

              // Lista por fecha
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final items = byDay[day]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                          child: Text(
                            DateFormat.yMMMMEEEEd(kLocaleEs).format(day),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        ...items.map((j) {
                          final timeStr = j.timeOfDay == null ? '' : ' • ${NotifService.formatAmPm(j.timeOfDay!)}';
                          final loc = (j.locationSnapshot ?? '').trim();

                          final montoStr = (j.isDone && j.montoCrc != null && j.montoCrc! > 0)
                              ? ' • ${formatCrc(j.montoCrc!)}'
                              : '';

                          final prov = _provinciaFromUbic(j.locationSnapshot);
                          final provColor = _colorProvincia(prov);

                          final topLine = '$prov • ${DateFormat.yMMMd(kLocaleEs).format(j.fecha)}$timeStr$montoStr';
                          final subText = loc.isEmpty ? topLine : '$topLine\n$loc';

                          final pdfUrl = j.numeroGarantiaCertificado == null
                              ? null
                              : ref.read(garantiasRepoProvider).getByJobId(j.id)?.pdfUrl;

                          return Card(
                            child: ListTile(
                              leading: _dotProvincia(provColor, size: 14),
                              title: Text(
                                j.titulo,
                                style: TextStyle(
                                  decoration: j.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(subText),
                              isThreeLine: loc.isNotEmpty,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((pdfUrl ?? '').trim().isNotEmpty)
                                    IconButton(
                                      tooltip: 'Ver certificado',
                                      icon: const Icon(Icons.picture_as_pdf),
                                      onPressed: () => launchUrl(Uri.parse(pdfUrl!), mode: LaunchMode.externalApplication),
                                    ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => JobDetailScreen(day: day, job: j)),
                                );
                                if (!mounted) return;
                                setState(() {});
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Lee todo desde Hive (kJobsBox)
  // ✅ + DEDUPE por id: si por alguna razón existe el mismo id repetido,
  //    nos quedamos con la versión "mejor" (prioriza isDone=true y luego la más reciente).
  List<JobItem> _getAllJobsFromHive() {
    final box = Hive.box(kJobsBox);
    final out = <JobItem>[];

    for (final dynamic k in box.keys) {
      final key = k.toString();

      // solo keys tipo YYYY-MM-DD
      try {
        DateTime.parse('${key}T00:00:00');
      } catch (_) {
        continue;
      }

      final raw = box.get(key, defaultValue: []) as List;
      for (final e in raw) {
        out.add(JobItem.fromMap(Map<String, dynamic>.from(e)));
      }
    }

    // ✅ DEDUPE por id (evita que se vea en "pendientes" y "hechos" a la vez)
    final byId = <String, JobItem>{};

    bool isBetter(JobItem a, JobItem b) {
      // 1) preferir done
      if (a.isDone != b.isDone) return a.isDone;

      // 2) preferir el que tenga doneAt más reciente (si existe)
      DateTime? parseIso(String? s) {
        if (s == null || s.isEmpty) return null;
        try {
          return DateTime.parse(s);
        } catch (_) {
          return null;
        }
      }

      final ad = parseIso(a.doneAtIso);
      final bd = parseIso(b.doneAtIso);
      if (ad != null && bd != null && ad != bd) return ad.isAfter(bd);
      if (ad != null && bd == null) return true;
      if (ad == null && bd != null) return false;

      // 3) si empatan: preferir fecha más reciente
      final af = DateTime(a.fecha.year, a.fecha.month, a.fecha.day);
      final bf = DateTime(b.fecha.year, b.fecha.month, b.fecha.day);
      if (af != bf) return af.isAfter(bf);

      // 4) si empatan: preferir el que tenga hora definida
      final ah = a.timeMinutes ?? 99999;
      final bh = b.timeMinutes ?? 99999;
      if (ah != bh) return ah < bh;

      // 5) si empatan: preferir el que tenga monto
      final am = a.montoCrc ?? 0;
      final bm = b.montoCrc ?? 0;
      if (am != bm) return am > bm;

      return false;
    }

    for (final j in out) {
      final prev = byId[j.id];
      if (prev == null) {
        byId[j.id] = j;
      } else {
        byId[j.id] = isBetter(j, prev) ? j : prev;
      }
    }

    final deduped = byId.values.toList();

    // Orden por fecha+hora
    deduped.sort((a, b) {
      final da = DateTime(a.fecha.year, a.fecha.month, a.fecha.day);
      final db = DateTime(b.fecha.year, b.fecha.month, b.fecha.day);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return (a.timeMinutes ?? 99999).compareTo(b.timeMinutes ?? 99999);
    });

    return deduped;
  }

  JobItem? _getNextPendingFromList(List<JobItem> all) {
    final now = DateTime.now();
    final pending = all.where((j) => !j.isDone).toList();

    DateTime toDateTime(JobItem j) {
      if (j.timeMinutes == null) {
        return DateTime(j.fecha.year, j.fecha.month, j.fecha.day, 23, 59);
      }
      final h = j.timeMinutes! ~/ 60;
      final m = j.timeMinutes! % 60;
      return DateTime(j.fecha.year, j.fecha.month, j.fecha.day, h, m);
    }

    pending.sort((a, b) => toDateTime(a).compareTo(toDateTime(b)));

    for (final j in pending) {
      if (!toDateTime(j).isBefore(now)) return j;
    }
    return pending.isEmpty ? null : pending.first;
  }

  String _provinciaFromUbic(String? ubic) {
    final t = (ubic ?? '').trim().toLowerCase();
    if (t.isEmpty) return 'Sin ubicacion';

    final norm = t
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (norm.contains('cartago')) return 'Cartago';
    if (norm.contains('san jose') || norm.contains('sanjose')) return 'San Jose';
    if (norm.contains('heredia')) return 'Heredia';
    if (norm.contains('alajuela')) return 'Alajuela';
    if (norm.contains('limon')) return 'Limon';
    if (norm.contains('guanacaste')) return 'Guanacaste';
    if (norm.contains('puntarenas')) return 'Puntarenas';

    return 'Sin ubicacion';
  }

  Color _colorProvincia(String provincia) {
    switch (provincia) {
      case 'Cartago':
        return Colors.blue;
      case 'San Jose':
        return Colors.purple;
      case 'Heredia':
        return Colors.yellow;
      case 'Alajuela':
        return Colors.red;
      case 'Limon':
        return Colors.green;
      case 'Guanacaste':
        return Colors.white;
      case 'Puntarenas':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _dotProvincia(Color c, {double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha:0.18)),
      ),
    );
  }
}