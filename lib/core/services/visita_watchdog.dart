import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/services/visita_cleanup_service.dart';

/// Revisa Visitas vencidas al entrar a Home y cada 30 minutos mientras la
/// app sigue abierta. Es un respaldo del cron del servidor (que hace lo
/// mismo para el job en Firestore aunque el teléfono esté apagado) - acá
/// se completa la parte que el cron no puede hacer solo: borrar también el
/// ClientItem huérfano, que vive solo en Hive local.
class VisitaWatchdog {
  static Timer? _timer;

  static void start(WidgetRef ref) {
    _revisar(ref);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _revisar(ref));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _revisar(WidgetRef ref) async {
    try {
      final borradas = await VisitaCleanupService.revisarVisitasVencidas(
        jobsRepo: ref.read(jobsRepoProvider),
        clientsRepo: ref.read(clientsRepoProvider),
        garantiasRepo: ref.read(garantiasRepoProvider),
      );
      if (borradas > 0) {
        debugPrint('VisitaWatchdog: $borradas visita(s) vencida(s) borrada(s)');
      }
    } catch (e) {
      debugPrint('VisitaWatchdog: error revisando visitas vencidas: $e');
    }
  }
}
