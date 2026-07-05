import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/data/repositories/jobs_repository.dart';
import 'package:portones_mym/features/clients/data/repositories/clients_repository.dart';
import 'package:portones_mym/features/garantias/data/repositories/garantias_repository.dart';

/// Borra una Visita (job tipo Visita) y, si corresponde, el cliente
/// asociado - en un único lugar, usado tanto por el borrado manual (botón
/// en el detalle) como por la revisión automática de las 24h.
///
/// El cliente SOLO se borra si:
/// 1. Se creó desde el flujo de Visita (creadoPorVisita == true), Y
/// 2. No tiene ningún otro job (Visita o Trabajo) asociado, Y
/// 3. No tiene ninguna garantía asociada.
///
/// Esto evita borrar el historial de un cliente que ya tenía otro Trabajo
/// o garantía antes de esta Visita puntual.
class VisitaCleanupService {
  static Future<void> borrarVisitaYClienteSiHuerfano({
    required JobsRepository jobsRepo,
    required ClientsRepository clientsRepo,
    required GarantiasRepository garantiasRepo,
    required JobItem visita,
  }) async {
    final day = DateTime(visita.fecha.year, visita.fecha.month, visita.fecha.day);
    await jobsRepo.deleteJob(day, visita.id);

    final phoneKey = visita.clientPhoneKey;
    if (phoneKey == null || phoneKey.isEmpty) return;

    final cliente = clientsRepo.getByPhoneKey(phoneKey);
    if (cliente == null || !cliente.creadoPorVisita) return;

    final tieneOtroJob = jobsRepo.getAllEvents().values.any(
          (jobsDelDia) => jobsDelDia.any((j) => j.id != visita.id && j.clientPhoneKey == phoneKey),
    );
    if (tieneOtroJob) return;

    final tieneGarantia = garantiasRepo.getAll().any((g) => g.phoneKey == phoneKey);
    if (tieneGarantia) return;

    await clientsRepo.deleteByPhoneKey(phoneKey);
  }

  /// Revisa todas las Visitas locales y borra (con su cliente si aplica)
  /// las que llevan más de 24h vencidas sin marcarse como realizadas.
  /// Se llama al abrir la app y periódicamente mientras está abierta - es
  /// un respaldo del cron del servidor, que hace lo mismo para el job en
  /// Firestore aunque el teléfono esté apagado.
  static Future<int> revisarVisitasVencidas({
    required JobsRepository jobsRepo,
    required ClientsRepository clientsRepo,
    required GarantiasRepository garantiasRepo,
  }) async {
    final ahora = DateTime.now();
    var borradas = 0;

    final todasLasVisitas = jobsRepo.getAllEvents().values
        .expand((lista) => lista)
        .where((j) => j.esVisita && !j.isDone)
        .toList();

    for (final visita in todasLasVisitas) {
      final minutos = visita.timeMinutes ?? 0;
      final fechaHora = DateTime(
        visita.fecha.year,
        visita.fecha.month,
        visita.fecha.day,
      ).add(Duration(minutes: minutos));

      if (ahora.difference(fechaHora) > const Duration(hours: 24)) {
        await borrarVisitaYClienteSiHuerfano(
          jobsRepo: jobsRepo,
          clientsRepo: clientsRepo,
          garantiasRepo: garantiasRepo,
          visita: visita,
        );
        borradas++;
      }
    }

    return borradas;
  }
}
