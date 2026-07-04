// lib/features/whatsapp/presentation/agendar_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:portones_mym/core/services/job_notif_service.dart';
import 'package:portones_mym/features/clients/data/repositories/clients_repository.dart';

class AgendarBottomSheet extends StatefulWidget {
  const AgendarBottomSheet({
    super.key,
    required this.telefono,
    required this.nombreCliente,
    this.provinciaCliente,
  });

  final String telefono;
  final String nombreCliente;
  final String? provinciaCliente;

  @override
  State<AgendarBottomSheet> createState() => _AgendarBottomSheetState();
}

class _AgendarBottomSheetState extends State<AgendarBottomSheet> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _diaFocused     = DateTime.now();
  List<Map<String, dynamic>> _jobsDelDia = [];
  List<Map<String, dynamic>> _todosLosJobs = [];
  bool _cargando  = true;
  bool _guardando = false;

  // Formulario
  final _tituloCtrl = TextEditingController();
  final _montoCtrl  = TextEditingController();
  TimeOfDay _hora   = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _cargarJobs();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarJobs() async {
    setState(() => _cargando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('jobs')
          .where('ownerUid', isEqualTo: uid)
          .where('deleted', isEqualTo: false)
          .get();

      _todosLosJobs = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      _filtrarJobsDelDia(_diaSeleccionado);
    } catch (e) {
      debugPrint('Error cargando jobs: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarJobsDelDia(DateTime dia) {
    _jobsDelDia = _todosLosJobs.where((job) {
      final fecha = (job['fecha'] as Timestamp?)?.toDate();
      if (fecha == null) return false;
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  List<Map<String, dynamic>> _jobsParaDia(DateTime dia) {
    return _todosLosJobs.where((job) {
      final fecha = (job['fecha'] as Timestamp?)?.toDate();
      if (fecha == null) return false;
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _agendar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá el tipo de trabajo')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final id = const Uuid().v4();
      final fechaConHora = DateTime(
        _diaSeleccionado.year,
        _diaSeleccionado.month,
        _diaSeleccionado.day,
        _hora.hour,
        _hora.minute,
      );
      final ahora = DateTime.now();
      final monto = int.tryParse(_montoCtrl.text.trim().replaceAll(',', '').replaceAll('.', ''));

      await FirebaseFirestore.instance.collection('jobs').doc(id).set({
        'id':                  id,
        'ownerUid':            uid,
        'titulo':              _tituloCtrl.text.trim(),
        'fecha':               Timestamp.fromDate(fechaConHora),
        'clientNameSnapshot':  widget.nombreCliente,
        'clientPhoneKey':      widget.telefono.replaceAll('+', '').replaceAll(' ', ''),
        'locationSnapshot':    widget.provinciaCliente ?? '',
        'montoCrc':            monto,
        'isDone':              false,
        'deleted':             false,
        'doneAtIso':           null,
        'nextVisitIso':        null,
        'timeMinutes':         _hora.hour * 60 + _hora.minute,
        'deviceId':            'app_${ahora.millisecondsSinceEpoch}',
        'createdAtMs':         ahora.millisecondsSinceEpoch,
        'updatedAtMs':         ahora.millisecondsSinceEpoch,
        'serverUpdatedAt':     FieldValue.serverTimestamp(),
        'sync': {
          'createdAt':    ahora.toIso8601String(),
          'updatedAt':    ahora.toIso8601String(),
          'lastSyncedAt': null,
          'isDirty':      true,
          'isDeleted':    false,
          'deviceId':     'app_${ahora.millisecondsSinceEpoch}',
          'version':      1,
        },
      });

      await ClientsRepository().upsert(
        nombre: widget.nombreCliente,
        telefono: widget.telefono,
        ubicacionTexto: widget.provinciaCliente ?? '',
      );

      final body = (widget.provinciaCliente != null && widget.provinciaCliente!.trim().isNotEmpty)
          ? widget.provinciaCliente!.trim()
          : widget.nombreCliente.trim();

      await JobNotifService.scheduleCascade(
        jobId: id,
        titulo: _tituloCtrl.text.trim(),
        day: _diaSeleccionado,
        timeMinutes: _hora.hour * 60 + _hora.minute,
        body: body,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Agendado para ${DateFormat('dd/MM/yyyy', 'es').format(fechaConHora)} a las ${_hora.format(context)}'),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF25D366)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agendar trabajo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.nombreCliente,
                          style: const TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
              children: [
                // Calendario
                TableCalendar(
                  locale: 'es_ES',
                  firstDay: DateTime.now().subtract(const Duration(days: 30)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _diaFocused,
                  selectedDayPredicate: (day) => isSameDay(day, _diaSeleccionado),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  eventLoader: (day) => _jobsParaDia(day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _diaSeleccionado = selected;
                      _diaFocused = focused;
                      _filtrarJobsDelDia(selected);
                    });
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    defaultTextStyle: const TextStyle(color: Colors.white),
                    weekendTextStyle: const TextStyle(color: Colors.white70),
                    outsideTextStyle: const TextStyle(color: Colors.white24),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    weekendStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

                const Divider(),

                // Jobs del día seleccionado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Trabajos del ${DateFormat('dd/MM/yyyy', 'es').format(_diaSeleccionado)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),

                if (_jobsDelDia.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Sin trabajos agendados para este día',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  )
                else
                  ..._jobsDelDia.map((job) {
                    final fecha = (job['fecha'] as Timestamp?)?.toDate();
                    final hora = fecha != null ? DateFormat('HH:mm').format(fecha) : '--:--';
                    final titulo = (job['titulo'] ?? 'Sin título').toString();
                    final cliente = (job['clientNameSnapshot'] ?? '').toString();
                    final isDone = job['isDone'] ?? false;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF25D366).withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF25D366).withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle : Icons.schedule,
                            color: isDone ? const Color(0xFF25D366) : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (cliente.isNotEmpty)
                                  Text(cliente, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(hora, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    );
                  }),

                const Divider(height: 32),

                // Formulario de agendamiento
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agendar en este día',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),

                      // Tipo de trabajo
                      const Text('Tipo de trabajo *',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tituloCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ej: Instalación, Visita técnica, Mantenimiento',
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Hora
                      const Text('Hora', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _seleccionarHora,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white54, size: 20),
                              const SizedBox(width: 10),
                              Text(_hora.format(context),
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monto
                      const Text('Monto (opcional)',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Ej: 195000',
                          prefixText: '₡ ',
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Resumen
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Resumen', style: TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            _resumenItem('Cliente', widget.nombreCliente),
                            _resumenItem('Teléfono', widget.telefono),
                            if ((widget.provinciaCliente ?? '').isNotEmpty)
                              _resumenItem('Provincia', widget.provinciaCliente!),
                            _resumenItem('Fecha', DateFormat('dd/MM/yyyy', 'es').format(_diaSeleccionado)),
                            _resumenItem('Hora', _hora.format(context)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón agendar
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _guardando ? null : _agendar,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _guardando
                              ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.calendar_today),
                          label: Text(
                            _guardando ? 'Agendando...' : 'Confirmar agendamiento',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenItem(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}