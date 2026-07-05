import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/services/notif_service.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/job_dialogs.dart';

/// Formulario para agendar una Visita técnica previa (sin costo, para
/// cotizar). La ubicación normalmente llega por WhatsApp el día de la
/// visita, no al agendarla - por eso queda opcional/vacía acá y se
/// completa después editando el job.
class AgregarVisitaScreen extends ConsumerStatefulWidget {
  const AgregarVisitaScreen({
    super.key,
    required this.day,
    this.nombreInicial,
    this.telefonoInicial,
    this.ubicacionInicial,
  });

  final DateTime day;
  final String? nombreInicial;
  final String? telefonoInicial;
  final String? ubicacionInicial;

  @override
  ConsumerState<AgregarVisitaScreen> createState() => _AgregarVisitaScreenState();
}

class _AgregarVisitaScreenState extends ConsumerState<AgregarVisitaScreen> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _ubicCtrl;
  final _motivoCtrl = TextEditingController();

  late DateTime _fecha;
  TimeOfDay? _pickedTime;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial ?? '');
    _telefonoCtrl = TextEditingController(text: widget.telefonoInicial ?? '');
    _ubicCtrl = TextEditingController(text: widget.ubicacionInicial ?? '');
    _fecha = widget.day;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _ubicCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) setState(() => _fecha = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _elegirHora() async {
    final t = await JobDialogs.pickTimeCupertino12h(context, initial: _pickedTime ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => _pickedTime = t);
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final tel = _telefonoCtrl.text.trim();

    if (nombre.isEmpty || tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente y teléfono son obligatorios')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final jobsRepo = ref.read(jobsRepoProvider);
      final clientsRepo = ref.read(clientsRepoProvider);

      final ubic = _ubicCtrl.text.trim();
      final phoneKey = await clientsRepo.upsert(
        nombre: nombre,
        telefono: tel,
        ubicacionTexto: ubic,
        creadoPorVisita: true,
      );
      if (!mounted) return;

      final minutes = _pickedTime == null ? null : (_pickedTime!.hour * 60 + _pickedTime!.minute);
      final motivo = _motivoCtrl.text.trim();

      await jobsRepo.addJob(
        day: _fecha,
        titulo: motivo.isEmpty ? 'Visita técnica' : motivo,
        timeMinutes: minutes,
        clientPhoneKey: phoneKey,
        clientNameSnapshot: nombre,
        locationSnapshot: ubic.isEmpty ? null : ubic,
        tipo: kTipoJobVisita,
        motivoVisita: motivo.isEmpty ? null : motivo,
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd(kLocaleEs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar visita'),
        actions: [
          if (_guardando)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _guardar),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visita técnica previa, sin costo, para cotizar donde el cliente.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Cliente *'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono *'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ubicCtrl,
              decoration: const InputDecoration(
                labelText: 'Ubicación (opcional)',
                hintText: 'Se suele completar el día de la visita',
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today),
              label: Text(df.format(_fecha)),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text(_pickedTime == null ? 'Elegir hora' : NotifService.formatAmPm(_pickedTime!)),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo / nota (opcional)',
                hintText: 'Ej: Cotizar portón corredizo',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
