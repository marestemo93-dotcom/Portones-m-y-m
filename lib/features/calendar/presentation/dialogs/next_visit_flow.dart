import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/certificado_garantia_flow.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/visita_realizada_flow.dart';

class NextVisitFlow {
  static Future<void> run({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime day,
    required JobItem job,
    required bool done,
  }) async {
    final jobsRepo = ref.read(jobsRepoProvider);
    final garRepo = ref.read(garantiasRepoProvider);

    if (!done) {
      await jobsRepo.toggleDone(day: day, id: job.id, done: false);
      return;
    }

    // Visita: no aplica nada de lo que sigue (certificado, garantía,
    // próxima visita) - eso es solo para Trabajo. Marcar una Visita como
    // realizada dispara su propio flujo (agendar Trabajo con fecha nueva).
    if (job.esVisita) {
      await VisitaRealizadaFlow.run(context: context, ref: ref, day: day, visita: job);
      return;
    }

    // Certificado de garantía en PDF: solo para trabajos que todavía no
    // tienen uno generado. Si se cancela, no se marca "Listo" (mismo
    // comportamiento que cancelar cualquier otro paso de este flujo).
    if (job.numeroGarantiaCertificado == null) {
      final completado = await CertificadoGarantiaFlow.run(context: context, ref: ref, day: day, job: job);
      if (!context.mounted) return;
      if (!completado) return;
    }

    final garMonths = await _pickGarantiaMonths(context);
    if (!context.mounted) return;
    if (garMonths == null) return;

    if (garMonths == 0) {
      await garRepo.deleteByJobId(job.id);
    } else {
      await garRepo.upsertFromJob(job: job, months: garMonths);
    }
    if (!context.mounted) return;

    await jobsRepo.toggleDone(day: day, id: job.id, done: true);
    if (!context.mounted) return;

    final months = await _pickNextVisitMonths(context);
    if (!context.mounted) return;
    if (months == null || months == 0) return;

    final title = await _promptNextVisitTitle(context, initial: job.titulo);
    if (!context.mounted) return;
    if (title == null || title.trim().isEmpty) return;

    final baseDay = DateTime(day.year, day.month, day.day);
    final nextDay = _addMonthsClamped(baseDay, months);

    await jobsRepo.addNextVisitFromJob(
      base: job,
      toDay: nextDay,
      timeMinutes: null,
      titleOverride: title.trim(),
    );

    await jobsRepo.updateJobInDay(
      day: day,
      id: job.id,
      nextVisitIso: nextDay.toIso8601String(),
    );
  }

  static Future<int?> _pickGarantiaMonths(BuildContext context) {
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
                child: Text('Garantía', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final m in options)
                ListTile(
                  title: Text(m == 0 ? 'Sin garantía (0)' : '$m meses'),
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Future<int?> _pickNextVisitMonths(BuildContext context) {
    const options = <int>[0, 3, 6, 8, 12, 24];

    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('¿Agendar próxima visita?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              for (final m in options)
                ListTile(
                  title: Text(m == 0 ? 'No agendar' : '$m meses'),
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Future<String?> _promptNextVisitTitle(BuildContext context, {required String initial}) async {
    final ctrl = TextEditingController(text: initial);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la próxima visita'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Trabajo', hintText: 'Ej: Revisión portón'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );

    ctrl.dispose();
    return result;
  }

  static DateTime _addMonthsClamped(DateTime d, int monthsToAdd) {
    final m = d.month + monthsToAdd;
    final newYear = d.year + ((m - 1) ~/ 12);
    final newMonth = ((m - 1) % 12) + 1;

    final lastDay = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = d.day > lastDay ? lastDay : d.day;

    return DateTime(newYear, newMonth, newDay);
  }
}