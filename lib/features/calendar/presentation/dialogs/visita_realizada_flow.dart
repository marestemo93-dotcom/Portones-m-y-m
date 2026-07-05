import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/agregar_trabajo_screen.dart';

/// Se dispara al marcar una Visita como "Realizada" (desde el detalle o
/// desde el checkbox de la lista del día). Pide una fecha NUEVA (no asume
/// que el trabajo es el mismo día de la visita) y abre el formulario de
/// Trabajo precargado con los datos del cliente de la visita. La visita en
/// sí queda marcada isDone=true (no se borra - eso solo pasa si vence sin
/// confirmarse, ver VisitaCleanupService).
///
/// Extraído como flujo compartido para que tanto job_detail_screen.dart
/// como next_visit_flow.dart (checkbox de la lista del día) tengan
/// exactamente el mismo comportamiento, sin lógica duplicada.
class VisitaRealizadaFlow {
  /// Devuelve true solo si se completó todo el flujo (fecha elegida +
  /// Trabajo creado + Visita marcada como realizada). Devuelve false si el
  /// usuario canceló en cualquier punto - en ese caso la Visita NO se marca.
  static Future<bool> run({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime day,
    required JobItem visita,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: visita.fecha.add(const Duration(days: 1)),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('es', 'ES'),
      helpText: 'Agendar día de trabajo',
    );
    if (pickedDate == null || !context.mounted) return false;

    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AgregarTrabajoScreen(
          day: pickedDate,
          nombreInicial: visita.clientNameSnapshot,
          telefonoInicial: visita.clientPhoneKey,
          ubicacionInicial: visita.locationSnapshot,
        ),
        fullscreenDialog: true,
      ),
    );
    if (creado != true || !context.mounted) return false;

    final jobsRepo = ref.read(jobsRepoProvider);
    await jobsRepo.updateJobInDay(
      day: day,
      id: visita.id,
      isDone: true,
      doneAtIso: DateTime.now().toIso8601String(),
    );
    return true;
  }
}
