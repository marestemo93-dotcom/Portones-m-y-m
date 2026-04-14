import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/garantias_repository.dart'; // addMonths(...)
import '../../../data/models/garantia_item.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/features/calendar/presentation/screens/job_detail_screen.dart';

enum GarFilter { active, expired, all }

class GarantiasTab extends ConsumerStatefulWidget {
  const GarantiasTab({super.key});

  @override
  ConsumerState<GarantiasTab> createState() => _GarantiasTabState();
}

class _GarantiasTabState extends ConsumerState<GarantiasTab> {
  String _q = '';
  GarFilter _filter = GarFilter.active;

  final _scrollCtrl = ScrollController();

  // keys estables por jobId (NO borrar en build)
  final Map<String, GlobalKey> _tileKeys = {};

  String? _highlightJobId;

  late final ProviderSubscription<String?> _targetSub;

  static const _provOrder = <String>[
    'Cartago',
    'San Jose',
    'Heredia',
    'Alajuela',
    'Guanacaste',
    'Puntarenas',
    'Limon',
    'Sin ubicacion',
  ];

  @override
  void initState() {
    super.initState();

    // ✅ listenManual es lo correcto en initState
    _targetSub = ref.listenManual<String?>(
      garantiaTargetJobIdProvider,
          (prev, next) async {
        if (next == null) return;

        // limpiar target para que no se repita
        ref.read(garantiaTargetJobIdProvider.notifier).state = null;

        // esperar a que renderice
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _scrollToJobId(next);
        });
      },
    );
  }

  @override
  void dispose() {
    _targetSub.close();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrollToJobId(String jobId) async {
    final key = _tileKeys[jobId];
    if (key == null) return;

    final ctx = key.currentContext;
    if (ctx == null) return;

    if (!mounted) return;
    setState(() => _highlightJobId = jobId);

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _highlightJobId = null);
  }

  @override
  Widget build(BuildContext context) {
    final garRepo = ref.watch(garantiasRepoProvider);
    final all = garRepo.getAll();

    final q = _q.trim().toLowerCase();
    final filtered = all.where((g) {
      if (_filter == GarFilter.active && g.isExpired) return false;
      if (_filter == GarFilter.expired && !g.isExpired) return false;

      if (q.isEmpty) return true;

      final tTrabajo = g.tituloTrabajo.toLowerCase();
      final tNombre = (g.clientName ?? '').toLowerCase();
      final tPhone = (g.phoneKey ?? '').toLowerCase();
      final tLoc = (g.location ?? '').toLowerCase();
      final tProv = g.provincia.toLowerCase();

      return tTrabajo.contains(q) ||
          tNombre.contains(q) ||
          tPhone.contains(q) ||
          tLoc.contains(q) ||
          tProv.contains(q);
    }).toList();

    final grouped = <String, List<GarantiaItem>>{
      for (final p in _provOrder) p: <GarantiaItem>[],
    };

    for (final g in filtered) {
      final p = _provOrder.contains(g.provincia) ? g.provincia : 'Sin ubicacion';
      grouped[p]!.add(g);

      // ✅ asegurar key estable
      _tileKeys.putIfAbsent(g.jobId, () => GlobalKey());
    }

    for (final p in _provOrder) {
      grouped[p]!.sort((a, b) {
        final c = a.expiresAt.compareTo(b.expiresAt);
        if (c != 0) return c;
        return a.fechaTrabajo.compareTo(b.fechaTrabajo);
      });
    }

    final hasAny = grouped.values.any((list) => list.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Garantías')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, teléfono, provincia, trabajo…',
                filled: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Activas'),
                  selected: _filter == GarFilter.active,
                  onSelected: (_) => setState(() => _filter = GarFilter.active),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Vencidas'),
                  selected: _filter == GarFilter.expired,
                  onSelected: (_) => setState(() => _filter = GarFilter.expired),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filter == GarFilter.all,
                  onSelected: (_) => setState(() => _filter = GarFilter.all),
                ),
              ],
            ),
          ),

          if (!hasAny)
            Expanded(
              child: Center(
                child: Text(
                  'No hay garantías para mostrar.',
                  style: TextStyle(color: Colors.white.withOpacity(0.65)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final prov in _provOrder)
                    if (grouped[prov]!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ProvinciaHeader(
                        provincia: prov,
                        color: _colorProvincia(prov),
                        count: grouped[prov]!.length,
                      ),
                      const SizedBox(height: 6),
                      ...grouped[prov]!.map((g) {
                        final isHighlight = (_highlightJobId == g.jobId);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isHighlight
                                ? Border.all(color: Colors.amber, width: 2)
                                : null,
                          ),
                          child: _GarantiaTile(
                            key: _tileKeys[g.jobId],
                            g: g,
                            color: _colorProvincia(prov),
                            onTap: () => _openJobDetailIfExists(context, g.jobId),
                            onEdit: () async {
                              final newMonths = await _pickGarantiaMonths(context, current: g.months);
                              if (newMonths == null) return;

                              if (newMonths == 0) {
                                await garRepo.deleteByJobId(g.jobId);
                              } else {
                                final baseDay = DateTime(g.fechaTrabajo.year, g.fechaTrabajo.month, g.fechaTrabajo.day);
                                final exp = addMonths(baseDay, newMonths);

                                final updated = GarantiaItem(
                                  id: g.id,
                                  jobId: g.jobId,
                                  tituloTrabajo: g.tituloTrabajo,
                                  clientName: g.clientName,
                                  phoneKey: g.phoneKey,
                                  location: g.location,
                                  provincia: g.provincia,
                                  fechaTrabajo: g.fechaTrabajo,
                                  months: newMonths,
                                  expiresAt: exp,
                                );

                                // ✅ ocupa esta función en tu repo
                                await garRepo.upsertRaw(updated);
                              }

                              if (mounted) setState(() {});
                            },
                          ),
                        );
                      }),
                    ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<int?> _pickGarantiaMonths(BuildContext context, {required int current}) {
    const options = <int>[0, 3, 6, 12, 24];

    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Editar garantía', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final m in options)
                ListTile(
                  title: Text(m == 0 ? 'Quitar garantía (0)' : '$m meses'),
                  trailing: (m == current) ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openJobDetailIfExists(BuildContext context, String jobId) async {
    final jobsRepo = ref.read(jobsRepoProvider);
    final events = jobsRepo.getAllEvents();

    JobItem? found;
    for (final entry in events.entries) {
      for (final j in entry.value) {
        if (j.id == jobId) {
          found = j;
          break;
        }
      }
      if (found != null) break;
    }

    if (found == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el trabajo en el calendario/registro.')),
      );
      return;
    }

    final dayOnly = DateTime(found.fecha.year, found.fecha.month, found.fecha.day);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailScreen(day: dayOnly, job: found!)),
    );

    if (mounted) setState(() {});
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
}

class _ProvinciaHeader extends StatelessWidget {
  const _ProvinciaHeader({
    required this.provincia,
    required this.color,
    required this.count,
  });

  final String provincia;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(provincia, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _dot(Color c, {double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
    );
  }
}

class _GarantiaTile extends StatelessWidget {
  const _GarantiaTile({
    super.key,
    required this.g,
    required this.color,
    required this.onTap,
    required this.onEdit,
  });

  final GarantiaItem g;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd(kLocaleEs);

    final info1 = [
      if ((g.clientName ?? '').trim().isNotEmpty) (g.clientName ?? '').trim(),
      if ((g.phoneKey ?? '').trim().isNotEmpty) (g.phoneKey ?? '').trim(),
    ].join(' • ');

    final countdown = _monthsDaysText(g.expiresAt);

    final sub = [
      'Trabajo: ${df.format(g.fechaTrabajo)}',
      'Vence: ${df.format(g.expiresAt)}',
      countdown,
      if ((g.location ?? '').trim().isNotEmpty) (g.location ?? '').trim(),
    ].join('\n');

    return Card(
      child: ListTile(
        leading: _dot(color, size: 12),
        title: Text(
          g.tituloTrabajo,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            decoration: g.isExpired ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          '${info1.isEmpty ? '—' : info1}\n$sub',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _dot(Color c, {double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
    );
  }

  String _monthsDaysText(DateTime expiresAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);

    final expired = !exp.isAfter(today);

    DateTime from = expired ? exp : today;
    DateTime to = expired ? today : exp;

    int months = (to.year * 12 + to.month) - (from.year * 12 + from.month);
    DateTime anchor = _addMonths(from, months);

    if (anchor.isAfter(to)) {
      months -= 1;
      anchor = _addMonths(from, months);
    }

    final days = to.difference(anchor).inDays;
    return expired ? 'Vencida hace ${months}m ${days}d' : 'Vence en ${months}m ${days}d';
  }

  DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = ((d.month - 1 + months) % 12) + 1;

    final lastDay = DateTime(y, m + 1, 0).day;
    final newDay = d.day > lastDay ? lastDay : d.day;

    return DateTime(y, m, newDay);
  }
}
