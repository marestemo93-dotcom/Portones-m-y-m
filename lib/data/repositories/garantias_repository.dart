import 'package:hive/hive.dart';
import '../models/garantia_item.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/data/models/job_item.dart';

class GarantiasRepository {
  final Box _box = Hive.box(kGarantiasBox);

  GarantiaItem? getByJobId(String jobId) {
    final raw = _box.get(jobId);
    if (raw is Map) {
      return GarantiaItem.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> upsertRaw(GarantiaItem g) async {
    await _box.put(g.jobId, g.toMap());
  }

  /// months = 0 => NO guardar garantía (si existía la borra)
  Future<void> upsertFromJob({
    required JobItem job,
    required int months,
  }) async {
    if (months <= 0) {
      await deleteByJobId(job.id);
      return;
    }

    final provincia = provinciaFromUbic(job.locationSnapshot);
    final baseDay = DateTime(job.fecha.year, job.fecha.month, job.fecha.day);
    final expiresAt = addMonths(baseDay, months);

    final g = GarantiaItem(
      id: job.id,
      jobId: job.id,
      tituloTrabajo: job.titulo,
      fechaTrabajo: baseDay,
      months: months,
      expiresAt: expiresAt,
      provincia: provincia,
      clientName: job.clientNameSnapshot,
      phoneKey: job.clientPhoneKey,
      location: job.locationSnapshot,
    );

    await _box.put(job.id, g.toMap());
  }

  Future<void> deleteByJobId(String jobId) async {
    await _box.delete(jobId);
  }

  List<GarantiaItem> getAll() {
    final out = <GarantiaItem>[];
    for (final dynamic k in _box.keys) {
      final raw = _box.get(k);
      if (raw is Map) {
        out.add(GarantiaItem.fromMap(Map<String, dynamic>.from(raw)));
      }
    }
    return out;
  }
}

/// ======================
/// Helpers (provincia + meses)
/// ======================

String provinciaFromUbic(String? ubic) {
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
  if (norm.contains('guanacaste')) return 'Guanacaste';
  if (norm.contains('puntarenas')) return 'Puntarenas';
  if (norm.contains('limon')) return 'Limon';

  return 'Sin ubicacion';
}

DateTime addMonths(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = ((d.month - 1 + months) % 12) + 1;

  final lastDay = DateTime(y, m + 1, 0).day;
  final newDay = d.day > lastDay ? lastDay : d.day;

  return DateTime(y, m, newDay);
}
