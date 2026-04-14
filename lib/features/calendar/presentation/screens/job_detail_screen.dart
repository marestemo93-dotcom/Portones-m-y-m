
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/core/services/notif_service.dart';
import 'package:portones_mym/core/utils/date_utils.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.day, required this.job});

  final DateTime day;
  final JobItem job;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  late JobItem _job;

  late final TextEditingController _workCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _montoCtrl;

  TimeOfDay? _pickedTime; // editable

  @override
  void initState() {
    super.initState();
    _job = widget.job;

    _workCtrl = TextEditingController(text: _job.titulo);
    _nameCtrl = TextEditingController(text: _job.clientNameSnapshot ?? '');
    _phoneCtrl = TextEditingController(text: _job.clientPhoneKey ?? '');
    _locCtrl = TextEditingController(text: _job.locationSnapshot ?? '');
    _montoCtrl = TextEditingController(text: _job.montoCrc?.toStringAsFixed(0) ?? '');
    _pickedTime = _job.timeOfDay;
  }

  @override
  void dispose() {
    _workCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = ((d.month - 1 + months) % 12) + 1;
    final day = d.day;

    final lastDay = DateTime(y, m + 1, 0).day;
    final newDay = day > lastDay ? lastDay : day;

    return DateTime(y, m, newDay);
  }

  Future<DateTime?> _pickDate(BuildContext context, {required DateTime initial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('es', 'ES'),
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day);
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, {required TimeOfDay initial}) async {
    TimeOfDay tempTime = initial;

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: 300,
          color: Colors.black,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancelar'),
                  ),
                  const Text(
                    'Seleccionar hora',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, tempTime),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,   // 👈 FORMATO 12 HORAS
                    initialDateTime: DateTime(
                      2024,
                      1,
                      1,
                      initial.hour,
                      initial.minute,
                    ),
                    onDateTimeChanged: (d) {
                      tempTime = TimeOfDay(hour: d.hour, minute: d.minute);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  Future<void> _reloadFromRepo() async {
    final jobsRepo = ref.read(jobsRepoProvider);
    final list = jobsRepo.getForDay(widget.day);
    try {
      final fresh = list.firstWhere((j) => j.id == _job.id);
      setState(() => _job = fresh);
    } catch (_) {
      // si ya no existe (por ejemplo lo moviste), no hacemos nada
    }
  }

  Future<void> _saveEdits() async {
    final jobsRepo = ref.read(jobsRepoProvider);
    final clientsRepo = ref.read(clientsRepoProvider);

    // 1) upsert cliente si hay teléfono
    String? phoneKey;
    final phoneRaw = _phoneCtrl.text.trim();

    if (phoneRaw.isNotEmpty) {
      phoneKey = await clientsRepo.upsert(
        nombre: _nameCtrl.text.trim().isEmpty ? 'Cliente' : _nameCtrl.text.trim(),
        telefono: phoneRaw,
        ubicacionTexto: _locCtrl.text.trim(),
      );
    }

    // 2) hora -> minutes
    final minutes = _pickedTime == null ? null : (_pickedTime!.hour * 60 + _pickedTime!.minute);

    // 3) monto (si vacío => borrar, si número => guardar)
    final montoRaw = _montoCtrl.text.trim();
    final montoNorm = montoRaw.replaceAll('₡', '').replaceAll(',', '').trim();

    double? monto;
    if (montoNorm.isNotEmpty) {
      monto = double.tryParse(montoNorm);
    }

    await jobsRepo.updateJobInDay(
      day: widget.day,
      id: _job.id,
      titulo: _workCtrl.text.trim().isEmpty ? _job.titulo : _workCtrl.text.trim(),
      timeMinutes: minutes,
      clientPhoneKey: phoneKey ?? _job.clientPhoneKey,
      clientNameSnapshot: _nameCtrl.text.trim().isEmpty ? _job.clientNameSnapshot : _nameCtrl.text.trim(),
      locationSnapshot: _locCtrl.text.trim().isEmpty ? _job.locationSnapshot : _locCtrl.text.trim(),

      // ✅ monto
      montoCrc: monto,
      clearMonto: montoNorm.isEmpty, // si dejó vacío, lo borra
    );

    await _reloadFromRepo();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado ✅')),
      );
    }
  }

  Future<void> _showDoneScheduler() async {
    final jobsRepo = ref.read(jobsRepoProvider);

    final monthsOptions = const [3, 6, 8, 12, 24];
    int selectedMonths = 6;

    final nextWorkCtrl = TextEditingController(
      text: _workCtrl.text.trim().isEmpty ? _job.titulo : _workCtrl.text.trim(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Marcar como “Listo”'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('¿En cuántos meses querés agendar la próxima visita?'),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (ctx2, setState2) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: monthsOptions.map((m) {
                      final selected = (m == selectedMonths);
                      return ChoiceChip(
                        label: Text('$m meses'),
                        selected: selected,
                        onSelected: (_) => setState2(() => selectedMonths = m),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nextWorkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Trabajo para la próxima visita',
                  hintText: 'Ej: Mantenimiento',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        );
      },
    );

    if (result != true) {
      nextWorkCtrl.dispose();
      return;
    }

    // ✅ 1) calcular próxima fecha
    final baseDay = DateTime(_job.fecha.year, _job.fecha.month, _job.fecha.day);
    final nextDay = _addMonths(baseDay, selectedMonths);
    final minutes = _pickedTime == null ? _job.timeMinutes : (_pickedTime!.hour * 60 + _pickedTime!.minute);

    // ✅ 2) crear el nuevo job (queda en el calendario)
    await jobsRepo.addJob(
      day: nextDay,
      titulo: nextWorkCtrl.text.trim().isEmpty ? _job.titulo : nextWorkCtrl.text.trim(),
      timeMinutes: minutes,
      clientPhoneKey: _job.clientPhoneKey,
      clientNameSnapshot: _nameCtrl.text.trim().isEmpty ? _job.clientNameSnapshot : _nameCtrl.text.trim(),
      locationSnapshot: _locCtrl.text.trim().isEmpty ? _job.locationSnapshot : _locCtrl.text.trim(),
    );

    // ✅ 3) marcar este como listo + guardar nextVisitIso (NO borra)
    await jobsRepo.updateJobInDay(
      day: widget.day,
      id: _job.id,
      isDone: true,
      doneAtIso: DateTime.now().toIso8601String(),
      nextVisitIso: nextDay.toIso8601String(),
      titulo: _workCtrl.text.trim().isEmpty ? _job.titulo : _workCtrl.text.trim(),
      timeMinutes: minutes,
      clientNameSnapshot: _nameCtrl.text.trim().isEmpty ? _job.clientNameSnapshot : _nameCtrl.text.trim(),
      locationSnapshot: _locCtrl.text.trim().isEmpty ? _job.locationSnapshot : _locCtrl.text.trim(),
    );

    // ✅ 4) refrescar UI sin cerrar
    await _reloadFromRepo();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Listo ✅ Próxima visita agendada en ${DateFormat.yMMMMd(kLocaleEs).format(nextDay)}',
          ),
        ),
      );
    }

    nextWorkCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsRepo = ref.read(jobsRepoProvider);
    final clientsRepo = ref.read(clientsRepoProvider);

    final client = _job.clientPhoneKey == null ? null : clientsRepo.getByPhoneKey(_job.clientPhoneKey!);
    final nextVisit = _job.nextVisitDate;
    final nextVisitText = nextVisit == null ? '—' : DateFormat.yMMMMd(kLocaleEs).format(nextVisit);

    final timeStr = _pickedTime == null ? '—' : NotifService.formatAmPm(_pickedTime!);
    final gRepo = ref.watch(garantiasRepoProvider);
    final garantia = gRepo.getByJobId(_job.id);
    final garantiaText = (garantia == null)
        ? 'Sin garantía'
        : _warrantyCountdownText(garantia.expiresAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await jobsRepo.deleteJob(widget.day, _job.id);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ header fijo (sin Expanded suelto)
                  Row(
                    children: [
                      Icon(
                        _job.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _job.isDone ? Colors.green : Colors.white38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _job.titulo,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            decoration: _job.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                            color: _job.isDone ? Colors.white70 : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text('Fecha: ${DateFormat.yMMMMd(kLocaleEs).format(_job.fecha)}'),
                  Text('Hora: $timeStr'),
                  const SizedBox(height: 8),
                  Text('Próxima visita: $nextVisitText', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Garantía: $garantiaText',
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ),
                      if (garantia != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Ver'),
                          onPressed: () {
                            // ✅ manda al tab Garantías y le dice cuál abrir
                            ref.read(homeTabIndexProvider.notifier).state = 4; // tab 5
                            ref.read(garantiaTargetJobIdProvider.notifier).state = _job.id;

                            // ✅ cerrar el detalle para ver el tab
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),

                  const Divider(height: 24),

                  // ✅ EDITAR TODO
                  Text('Editar información:', style: TextStyle(color: Colors.white.withOpacity(0.75))),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _workCtrl,
                    decoration: const InputDecoration(labelText: 'Trabajo (ej: Mantenimiento)'),
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_pickedTime == null ? 'Elegir hora' : timeStr),
                    onPressed: () async {
                      final picked = await _pickTime(
                        context,
                        initial: _pickedTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) setState(() => _pickedTime = picked);
                    },
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del cliente'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locCtrl,
                    decoration: const InputDecoration(labelText: 'Ubicación'),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto (₡) (opcional)',
                      hintText: 'Ej: 450000',
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveEdits,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar cambios'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ ACCIONES (sin overflow)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_repeat),
                          label: const Text('Reagendar'),
                          onPressed: () async {
                            final pickedDate = await _pickDate(context, initial: _job.fecha);
                            if (pickedDate == null) return;

                            final pickedTime = await _pickTime(
                              context,
                              initial: _pickedTime ?? (_job.timeOfDay ?? const TimeOfDay(hour: 9, minute: 0)),
                            );
                            final minutes = pickedTime == null ? null : (pickedTime.hour * 60 + pickedTime.minute);

                            await jobsRepo.moveJob(
                              fromDay: widget.day,
                              id: _job.id,
                              toDay: pickedDate,
                              newTimeMinutes: minutes,
                            );

                            ref.read(selectedDayProvider.notifier).state = dayKey(pickedDate);

                            // al mover de día, sí conviene volver a la lista
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Próx visita'),
                          onPressed: () async {
                            final pickedDate = await _pickDate(
                              context,
                              initial: _job.fecha.add(const Duration(days: 30)),
                            );
                            if (pickedDate == null) return;

                            final pickedTime = await _pickTime(
                              context,
                              initial: _pickedTime ?? (_job.timeOfDay ?? const TimeOfDay(hour: 9, minute: 0)),
                            );
                            final minutes = pickedTime == null ? null : (pickedTime.hour * 60 + pickedTime.minute);

                            await jobsRepo.addJob(
                              day: pickedDate,
                              titulo: _workCtrl.text.trim().isEmpty ? _job.titulo : _workCtrl.text.trim(),
                              timeMinutes: minutes,
                              clientPhoneKey: _job.clientPhoneKey,
                              clientNameSnapshot:
                              _nameCtrl.text.trim().isEmpty ? _job.clientNameSnapshot : _nameCtrl.text.trim(),
                              locationSnapshot:
                              _locCtrl.text.trim().isEmpty ? _job.locationSnapshot : _locCtrl.text.trim(),
                            );

                            ref.read(selectedDayProvider.notifier).state = dayKey(pickedDate);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Próxima visita creada ✅')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ CHECK “LISTO” con opciones 3/6/8/12/24 meses (NO CIERRA)
                  Row(
                    children: [
                      Checkbox(
                        value: _job.isDone,
                        activeColor: Colors.green,
                        onChanged: (v) async {
                          if ((_job.isDone == false) && (v == true)) {
                            await _showDoneScheduler();
                            return;
                          }

                          // si lo desmarcan (true -> false)
                          await jobsRepo.updateJobInDay(
                            day: widget.day,
                            id: _job.id,
                            isDone: false,
                            doneAtIso: null,
                            nextVisitIso: null,
                          );
                          await _reloadFromRepo();
                        },
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _job.isDone ? Colors.green : Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          client?.nombre ?? _job.clientNameSnapshot ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.55)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Al marcar “Listo” te pregunta cada cuántos meses y crea la próxima visita en el calendario con nombre, teléfono, ubicación y el trabajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.65)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  String _warrantyCountdownText(DateTime expiresAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);

    if (!exp.isAfter(today)) return 'Garantía vencida';

    // Calcula meses aproximados “calendario” + días restantes
    int months = (exp.year - today.year) * 12 + (exp.month - today.month);
    DateTime anchor = DateTime(today.year, today.month + months, today.day);

    if (anchor.isAfter(exp)) {
      months -= 1;
      anchor = DateTime(today.year, today.month + months, today.day);
    }

    final days = exp.difference(anchor).inDays;

    if (months <= 0) return 'Quedan $days días';
    if (days <= 0) return 'Quedan $months mes${months == 1 ? '' : 'es'}';
    return 'Quedan $months mes${months == 1 ? '' : 'es'} $days día${days == 1 ? '' : 's'}';
  }
}