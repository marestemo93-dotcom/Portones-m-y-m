// lib/data/repositories/jobs_repository.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// ✅ FIRESTORE
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ AUTH (para que request.auth != null y no te bloquee reglas)
import 'package:firebase_auth/firebase_auth.dart';

import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/core/services/job_notif_service.dart';
import 'package:portones_mym/core/utils/date_utils.dart';

import 'package:portones_mym/core/sync/device_id.dart'; // ✅ NUEVO
import 'package:portones_mym/core/sync/sync_meta.dart'; // ✅ NUEVO

class JobsRepository {
  final _box = Hive.box(kJobsBox);
  final _tombBox = Hive.box(kJobsTombBox); // ✅ NUEVO
  final _uuid = const Uuid();

  static const String _kLastSyncMsKey = '__sync_jobs_last_ms';

  // ✅ Firestore collection
  CollectionReference<Map<String, dynamic>> get _jobsCol =>
      FirebaseFirestore.instance.collection('jobs');

  // =========================================================
  // ✅ AUTH HELPERS (NUEVO)  -> evita PERMISSION_DENIED por auth null
  // =========================================================

  Future<void>? _authInit;

  Future<void> _ensureAuth() {
    _authInit ??= () async {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    }();
    return _authInit!;
  }

  // =========================
  // ✅ FIRESTORE HELPERS
  // =========================

  /// Sube (upsert) a Firestore lo que está en el map (normal o tombstone).
  Future<void> _pushMapToFirestore(Map<String, dynamic> m) async {
    try {
      _ensureSyncMap(m);

      // ✅ Asegura user (request.auth != null)
      await _ensureAuth();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      final deviceId = await DeviceId.getOrCreate();
      final job = JobItem.fromMap(m);

      debugPrint(
          '🔥 Firestore upsert -> jobs/${job.id} titulo=${job.titulo} uid=$uid deviceId=$deviceId');

      // Usamos tu toFirestore y le agregamos ownerUid sin romper nada
      final data = job.toFirestore(deviceId: deviceId);
      if (uid != null && uid.isNotEmpty) {
        data['ownerUid'] = uid;
      }

      await _jobsCol.doc(job.id).set(
        data,
        SetOptions(merge: true),
      );

      debugPrint('✅ Firestore OK -> ${job.id}');
    } catch (e, st) {
      debugPrint('❌ Firestore ERROR: $e');
      debugPrint('$st');
    }
  }

  /// Helper para subir "tombstone" (borrado)
  Future<void> _pushTombstoneToFirestore(Map<String, dynamic> tomb) async {
    try {
      _ensureSyncMap(tomb);
      await _markDirty(tomb, deleted: true);
      await _pushMapToFirestore(tomb);
    } catch (e) {
      debugPrint('❌ Tombstone push error: $e');
    }
  }

  // ---------- LECTURA (igual que antes) ----------

  List<JobItem> getForDay(DateTime day) {
    final key = dayKey(day);
    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw
        .map((e) => JobItem.fromMap(Map<String, dynamic>.from(e)))
    // ✅ Oculta soft-deletes
        .where((j) => j.sync.isDeleted == false)
        .toList();

    list.sort((a, b) {
      final da = a.isDone ? 1 : 0;
      final db = b.isDone ? 1 : 0;
      if (da != db) return da.compareTo(db);

      final ta = a.timeMinutes ?? 99999;
      final tb = b.timeMinutes ?? 99999;
      if (ta != tb) return ta.compareTo(tb);

      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

    return list;
  }

  Map<DateTime, List<JobItem>> getAllEvents() {
    final Map<DateTime, List<JobItem>> map = {};
    for (final dynamic k in _box.keys) {
      final key = k.toString();
      DateTime date;
      try {
        date = DateTime.parse('${key}T00:00:00');
      } catch (_) {
        continue;
      }

      final raw = _box.get(key, defaultValue: []) as List;
      final items = raw
          .map((e) => JobItem.fromMap(Map<String, dynamic>.from(e)))
          .where((j) => j.sync.isDeleted == false)
          .toList();

      map[DateTime(date.year, date.month, date.day)] = items;
    }
    return map;
  }

  // ---------- SYNC HELPERS ----------

  Map<String, dynamic> _ensureSyncMap(Map<String, dynamic> m) {
    final sync = m['sync'];
    if (sync is Map) return m;

    // Si no existe, crea uno legacy compatible.
    m['sync'] = SyncMeta.legacy().toMap();
    m['createdAtMs'] ??= DateTime.now().millisecondsSinceEpoch;
    m['updatedAtMs'] ??= DateTime.now().millisecondsSinceEpoch;
    m['deleted'] ??= false;
    return m;
  }

  Future<void> _markDirty(Map<String, dynamic> m, {bool? deleted}) async {
    _ensureSyncMap(m);

    final deviceId = await DeviceId.getOrCreate();
    final now = DateTime.now();

    final current = SyncMeta.fromMap((m['sync'] as Map).cast<String, dynamic>());
    final next = current.copyWith(
      deviceId: (current.deviceId == 'legacy' || current.deviceId.isEmpty)
          ? deviceId
          : current.deviceId,
      isDirty: true,
      isDeleted: deleted ?? current.isDeleted,
      version: current.version + 1,
      updatedAt: now,
    );

    m['sync'] = next.toMap();

    // útiles para Firestore queries (no afectan lo viejo)
    m['updatedAtMs'] = next.updatedAt.millisecondsSinceEpoch;
    m['createdAtMs'] = next.createdAt.millisecondsSinceEpoch;
    m['deleted'] = next.isDeleted;
  }

  // Itera todos los jobs del box diario (O(n))
  Iterable<Map<String, dynamic>> _iterateAllDayJobMaps() sync* {
    for (final dynamic k in _box.keys) {
      final key = k.toString();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) continue;

      final raw = _box.get(key, defaultValue: []) as List;
      for (final e in raw) {
        yield Map<String, dynamic>.from(e as Map);
      }
    }
  }

  // ---------- Métodos para SyncService ----------

  /// Devuelve jobs locales con cambios pendientes (incluye borrados en tombBox)
  Future<List<JobItem>> getDirtyJobs() async {
    final List<JobItem> out = [];

    // 1) Cambios en jobs normales
    for (final m in _iterateAllDayJobMaps()) {
      _ensureSyncMap(m);
      final meta = SyncMeta.fromMap((m['sync'] as Map).cast<String, dynamic>());
      if (meta.isDirty) {
        out.add(JobItem.fromMap(m));
      }
    }

    // 2) Tombstones (borrados)
    for (final dynamic k in _tombBox.keys) {
      final raw = _tombBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        _ensureSyncMap(m);
        final meta =
        SyncMeta.fromMap((m['sync'] as Map).cast<String, dynamic>());
        if (meta.isDirty) {
          out.add(JobItem.fromMap(m));
        }
      }
    }

    return out;
  }

  /// Marca un job como sincronizado (si está en días o en tomb)
  Future<void> markJobSynced(String jobId) async {
    // 1) buscar en días
    for (final dynamic k in _box.keys) {
      final key = k.toString();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) continue;

      final raw = _box.get(key, defaultValue: []) as List;
      final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

      final idx = list.indexWhere((m) => m['id'] == jobId);
      if (idx != -1) {
        final m = list[idx];
        _ensureSyncMap(m);

        final meta =
        SyncMeta.fromMap((m['sync'] as Map).cast<String, dynamic>());
        final next = meta.copyWith(isDirty: false, lastSyncedAt: DateTime.now());

        m['sync'] = next.toMap();
        m['updatedAtMs'] = next.updatedAt.millisecondsSinceEpoch;
        m['deleted'] = next.isDeleted;

        list[idx] = m;
        await _box.put(key, list);
        return;
      }
    }

    // 2) si no está, buscar en tombstones
    final rawT = _tombBox.get(jobId);
    if (rawT is Map) {
      final m = Map<String, dynamic>.from(rawT);
      _ensureSyncMap(m);

      final meta = SyncMeta.fromMap((m['sync'] as Map).cast<String, dynamic>());
      final next = meta.copyWith(isDirty: false, lastSyncedAt: DateTime.now());

      m['sync'] = next.toMap();
      m['updatedAtMs'] = next.updatedAt.millisecondsSinceEpoch;
      m['deleted'] = next.isDeleted;

      await _tombBox.put(jobId, m);
    }
  }

  Future<int> getLastJobsSyncMs() async {
    final v = _box.get(_kLastSyncMsKey);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> setLastJobsSyncMs(int ms) async {
    await _box.put(_kLastSyncMsKey, ms);
  }

  Future<JobItem?> getJobById(String id) async {
    for (final dynamic k in _box.keys) {
      final key = k.toString();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) continue;

      final raw = _box.get(key, defaultValue: []) as List;
      for (final e in raw) {
        final m = Map<String, dynamic>.from(e as Map);
        if (m['id'] == id) return JobItem.fromMap(m);
      }
    }

    final t = _tombBox.get(id);
    if (t is Map) return JobItem.fromMap(Map<String, dynamic>.from(t));

    return null;
  }

  /// Aplica un job que viene del servidor (Firestore) a Hive
  Future<void> upsertFromRemote(JobItem job) async {
    final m = job.toMap();
    final isDeleted = job.sync.isDeleted;

    if (isDeleted) {
      await _tombBox.put(job.id, m);
      await _removeFromAnyDay(job.id);
      return;
    }

    final day = DateTime(job.fecha.year, job.fecha.month, job.fecha.day);
    final key = dayKey(day);

    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    final idx = list.indexWhere((x) => x['id'] == job.id);
    if (idx == -1) {
      list.add(m);
    } else {
      list[idx] = m;
    }
    await _box.put(key, list);

    if (_tombBox.containsKey(job.id)) {
      await _tombBox.delete(job.id);
    }
  }

  Future<void> _removeFromAnyDay(String id) async {
    for (final dynamic k in _box.keys) {
      final key = k.toString();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) continue;

      final raw = _box.get(key, defaultValue: []) as List;
      final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      final before = list.length;
      list.removeWhere((m) => m['id'] == id);
      if (list.length != before) {
        await _box.put(key, list);
        return;
      }
    }
  }

  // ---------- CRUD (misma lógica + dirty + Firestore) ----------

  Future<JobItem> addJob({
    required DateTime day,
    required String titulo,
    int? timeMinutes,
    String? clientPhoneKey,
    String? clientNameSnapshot,
    String? locationSnapshot,
    double? montoCrc,
  }) async {
    final key = dayKey(day);
    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    final deviceId = await DeviceId.getOrCreate();

    final job = JobItem(
      id: _uuid.v4(),
      titulo: titulo.trim(),
      fecha: DateTime(day.year, day.month, day.day),
      timeMinutes: timeMinutes,
      clientPhoneKey: clientPhoneKey,
      clientNameSnapshot: clientNameSnapshot,
      locationSnapshot: locationSnapshot,
      montoCrc: montoCrc,
      sync: SyncMeta.legacy().copyWith(deviceId: deviceId, isDirty: true),
    );

    final jobMap = job.toMap();
    _ensureSyncMap(jobMap);
    await _markDirty(jobMap, deleted: false);

    list.add(jobMap);
    await _box.put(key, list);

    // ✅ SUBIR A FIRESTORE (una sola vez)
    unawaited(_pushMapToFirestore(jobMap));

    if (job.timeMinutes != null && job.isDone == false) {
      final body =
      (job.locationSnapshot != null &&
          job.locationSnapshot!.trim().isNotEmpty)
          ? job.locationSnapshot!.trim()
          : (job.clientNameSnapshot != null &&
          job.clientNameSnapshot!.trim().isNotEmpty)
          ? job.clientNameSnapshot!.trim()
          : '';

      await JobNotifService.scheduleCascade(
        jobId: job.id,
        titulo: job.titulo,
        day: job.fecha,
        timeMinutes: job.timeMinutes!,
        body: body,
      );
    }

    return job;
  }

  /// ✅ Mantiene UX (desaparece del día), pero guarda tombstone para sync
  Future<void> deleteJob(DateTime day, String id) async {
    final key = dayKey(day);
    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    final idx = list.indexWhere((m) => m['id'] == id);
    if (idx != -1) {
      final tomb = Map<String, dynamic>.from(list[idx]);
      _ensureSyncMap(tomb);
      await _markDirty(tomb, deleted: true);
      await _tombBox.put(id, tomb);

      // ✅ SUBIR TOMBSTONE A FIRESTORE
      unawaited(_pushTombstoneToFirestore(tomb));
    }

    list.removeWhere((m) => m['id'] == id);
    await _box.put(key, list);

    unawaited(JobNotifService.cancelAllForJob(id));
  }

  Future<void> toggleDone({
    required DateTime day,
    required String id,
    required bool done,
  }) async {
    final key = dayKey(day);
    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    final idx = list.indexWhere((m) => m['id'] == id);
    if (idx == -1) return;

    list[idx]['isDone'] = done;
    list[idx]['doneAtIso'] = done ? DateTime.now().toIso8601String() : null;

    await _markDirty(list[idx]);
    await _box.put(key, list);

    // ✅ SUBIR A FIRESTORE
    unawaited(_pushMapToFirestore(list[idx]));

    if (done) {
      unawaited(JobNotifService.cancelAllForJob(id));
      return;
    }

    final minutes = list[idx]['timeMinutes'] as int?;
    if (minutes == null) return;

    final titulo = (list[idx]['titulo'] as String?) ?? 'Trabajo';

    DateTime fecha;
    try {
      fecha = DateTime.parse(list[idx]['fecha'] as String);
    } catch (_) {
      fecha = DateTime(day.year, day.month, day.day);
    }

    final body =
    ((list[idx]['locationSnapshot'] as String?)?.trim().isNotEmpty == true)
        ? (list[idx]['locationSnapshot'] as String).trim()
        : ((list[idx]['clientNameSnapshot'] as String?)?.trim().isNotEmpty ==
        true)
        ? (list[idx]['clientNameSnapshot'] as String).trim()
        : '';

    await JobNotifService.scheduleCascade(
      jobId: id,
      titulo: titulo,
      day: DateTime(fecha.year, fecha.month, fecha.day),
      timeMinutes: minutes,
      body: body,
    );
  }

  Future<void> updateJobInDay({
    required DateTime day,
    required String id,
    String? titulo,
    int? timeMinutes,
    bool? isDone,
    String? doneAtIso,
    String? nextVisitIso,
    String? clientPhoneKey,
    String? clientNameSnapshot,
    String? locationSnapshot,
    double? montoCrc,
    bool clearMonto = false,
  }) async {
    final key = dayKey(day);
    final raw = _box.get(key, defaultValue: []) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    final idx = list.indexWhere((m) => m['id'] == id);
    if (idx < 0) return;

    final m = list[idx];

    if (titulo != null) m['titulo'] = titulo;
    m['timeMinutes'] = timeMinutes;

    if (isDone != null) m['isDone'] = isDone;

    if (isDone == false) {
      m['doneAtIso'] = null;
    } else if (doneAtIso != null) {
      m['doneAtIso'] = doneAtIso;
    }

    if (nextVisitIso != null) m['nextVisitIso'] = nextVisitIso;

    if (clientPhoneKey != null) m['clientPhoneKey'] = clientPhoneKey;
    if (clientNameSnapshot != null) m['clientNameSnapshot'] = clientNameSnapshot;
    if (locationSnapshot != null) m['locationSnapshot'] = locationSnapshot;

    if (clearMonto) {
      m['montoCrc'] = null;
    } else if (montoCrc != null) {
      m['montoCrc'] = montoCrc;
    }

    await _markDirty(m);

    list[idx] = m;
    await _box.put(key, list);

    // ✅ SUBIR A FIRESTORE
    unawaited(_pushMapToFirestore(m));

    unawaited(JobNotifService.cancelAllForJob(id));

    final doneFinal = (m['isDone'] as bool?) ?? false;
    if (doneFinal) return;

    final minutesFinal = m['timeMinutes'] as int?;
    if (minutesFinal == null) return;

    DateTime fecha;
    try {
      fecha = DateTime.parse(m['fecha'] as String);
    } catch (_) {
      fecha = DateTime(day.year, day.month, day.day);
    }

    final tituloFinal = (m['titulo'] as String?) ?? 'Trabajo';

    final body =
    ((m['locationSnapshot'] as String?)?.trim().isNotEmpty == true)
        ? (m['locationSnapshot'] as String).trim()
        : ((m['clientNameSnapshot'] as String?)?.trim().isNotEmpty == true)
        ? (m['clientNameSnapshot'] as String).trim()
        : '';

    await JobNotifService.scheduleCascade(
      jobId: id,
      titulo: tituloFinal,
      day: DateTime(fecha.year, fecha.month, fecha.day),
      timeMinutes: minutesFinal,
      body: body,
    );
  }

  Future<void> moveJob({
    required DateTime fromDay,
    required String id,
    required DateTime toDay,
    int? newTimeMinutes,
  }) async {
    final fromKey = dayKey(fromDay);
    final toKey = dayKey(toDay);

    final fromRaw = _box.get(fromKey, defaultValue: []) as List;
    final fromList = fromRaw.map((e) => Map<String, dynamic>.from(e)).toList();

    final idx = fromList.indexWhere((m) => m['id'] == id);
    if (idx == -1) return;

    final jobMap = Map<String, dynamic>.from(fromList[idx]);
    fromList.removeAt(idx);
    await _box.put(fromKey, fromList);

    final newFecha = DateTime(toDay.year, toDay.month, toDay.day);
    jobMap['fecha'] = newFecha.toIso8601String();
    jobMap['timeMinutes'] = newTimeMinutes;

    await _markDirty(jobMap);

    final toRaw = _box.get(toKey, defaultValue: []) as List;
    final toList = toRaw.map((e) => Map<String, dynamic>.from(e)).toList();
    toList.add(jobMap);
    await _box.put(toKey, toList);

    // ✅ SUBIR A FIRESTORE
    unawaited(_pushMapToFirestore(jobMap));

    unawaited(JobNotifService.cancelAllForJob(id));

    final doneFinal = (jobMap['isDone'] as bool?) ?? false;
    if (doneFinal) return;

    final minutesFinal = jobMap['timeMinutes'] as int?;
    if (minutesFinal == null) return;

    final tituloFinal = (jobMap['titulo'] as String?) ?? 'Trabajo';

    final body =
    ((jobMap['locationSnapshot'] as String?)?.trim().isNotEmpty == true)
        ? (jobMap['locationSnapshot'] as String).trim()
        : ((jobMap['clientNameSnapshot'] as String?)?.trim().isNotEmpty ==
        true)
        ? (jobMap['clientNameSnapshot'] as String).trim()
        : '';

    await JobNotifService.scheduleCascade(
      jobId: id,
      titulo: tituloFinal,
      day: newFecha,
      timeMinutes: minutesFinal,
      body: body,
    );
  }

  Future<void> addNextVisitFromJob({
    required JobItem base,
    required DateTime toDay,
    int? timeMinutes,
    String? titleOverride,
  }) async {
    await addJob(
      day: toDay,
      titulo: (titleOverride ?? base.titulo).trim(),
      timeMinutes: timeMinutes,
      clientPhoneKey: base.clientPhoneKey,
      clientNameSnapshot: base.clientNameSnapshot,
      locationSnapshot: base.locationSnapshot,
    );
  }
}