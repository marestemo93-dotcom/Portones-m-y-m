import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/services/notif_service.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/job_dialogs.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/detalle_trabajo_editor.dart';

/// Pantalla completa para agendar un Trabajo desde el calendario. Reemplaza
/// el AlertDialog chico que existía antes en job_dialogs.dart - ya no
/// alcanzaba el espacio para productos + descuento + tabla.
class AgregarTrabajoScreen extends ConsumerStatefulWidget {
  const AgregarTrabajoScreen({
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
  ConsumerState<AgregarTrabajoScreen> createState() => _AgregarTrabajoScreenState();
}

class _AgregarTrabajoScreenState extends ConsumerState<AgregarTrabajoScreen> {
  final _tituloCtrl = TextEditingController();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _ubicCtrl;

  TimeOfDay? _pickedTime;
  bool _guardando = false;

  List<DetalleTrabajoLinea> _lineas = [];
  double? _descuentoValor;
  String _descuentoTipo = 'monto';
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial ?? '');
    _telefonoCtrl = TextEditingController(text: widget.telefonoInicial ?? '');
    _ubicCtrl = TextEditingController(text: widget.ubicacionInicial ?? '');
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _ubicCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final t = await JobDialogs.pickTimeCupertino12h(context, initial: _pickedTime ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => _pickedTime = t);
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El campo "Trabajo" es obligatorio')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final jobsRepo = ref.read(jobsRepoProvider);
      final clientsRepo = ref.read(clientsRepoProvider);

      final tel = _telefonoCtrl.text.trim();
      final nombre = _nombreCtrl.text.trim();
      final ubic = _ubicCtrl.text.trim();

      String? phoneKey;
      if (tel.isNotEmpty) {
        phoneKey = await clientsRepo.upsert(
          nombre: nombre.isEmpty ? 'Cliente' : nombre,
          telefono: tel,
          ubicacionTexto: ubic,
        );
        if (!mounted) return;
      }

      final minutes = _pickedTime == null ? null : (_pickedTime!.hour * 60 + _pickedTime!.minute);

      await jobsRepo.addJob(
        day: widget.day,
        titulo: titulo,
        timeMinutes: minutes,
        clientPhoneKey: phoneKey,
        clientNameSnapshot: nombre.isEmpty ? null : nombre,
        locationSnapshot: ubic.isEmpty ? null : ubic,
        montoCrc: _total > 0 ? _total : null,
        detalleTrabajo: _lineas,
        descuentoValor: _descuentoValor,
        descuentoTipo: _descuentoTipo,
      );

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar trabajo'),
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
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Trabajo', hintText: 'Ej: Mantenimiento portón'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Cliente (opcional)'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ubicCtrl,
              decoration: const InputDecoration(labelText: 'Ubicación (opcional)'),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text(_pickedTime == null ? 'Elegir hora' : NotifService.formatAmPm(_pickedTime!)),
            ),
            const SizedBox(height: 20),

            const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            DetalleTrabajoEditor(
              lineasIniciales: _lineas,
              descuentoValorInicial: _descuentoValor,
              descuentoTipoInicial: _descuentoTipo,
              onChanged: (lineas, descuentoValor, descuentoTipo, total) {
                _lineas = lineas;
                _descuentoValor = descuentoValor;
                _descuentoTipo = descuentoTipo;
                _total = total;
              },
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
