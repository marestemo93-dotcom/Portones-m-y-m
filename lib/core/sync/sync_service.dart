// lib/core/sync/sync_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:portones_mym/core/sync/device_id.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/data/repositories/jobs_repository.dart';
import 'package:portones_mym/data/firestore/firestore_jobs_datasource.dart';

class SyncService {
  SyncService({
    required this.jobsRepo,
    required this.remote,
  });

  final JobsRepository jobsRepo; // Hive local
  final FirestoreJobsDatasource remote; // Firestore

  bool _running = false;

  /// ✅ Push: sube todos los jobs dirty (incluye tombstones)
  Future<void> pushDirty() async {
    if (_running) return;
    _running = true;

    try {
      final deviceId = DeviceId.getOrCreate();

      final dirty = await jobsRepo.getDirtyJobs();
      if (dirty.isEmpty) return;

      for (final JobItem job in dirty) {
        try {
          await remote.upsertJob(job, deviceId: deviceId);
          await jobsRepo.markJobSynced(job.id);
        } catch (e) {
          debugPrint('❌ pushDirty error job=${job.id}: $e');
        }
      }
    } finally {
      _running = false;
    }
  }

  /// ✅ Pull: baja cambios desde Firestore desde lastSyncMs y los aplica a Hive
  Future<void> pull() async {
    if (_running) return;
    _running = true;

    try {
      final lastMs = await jobsRepo.getLastJobsSyncMs();
      final remoteJobs = await remote.fetchUpdatedSince(lastMs, includeDeleted: true);

      int maxMs = lastMs;

      for (final job in remoteJobs) {
        await jobsRepo.upsertFromRemote(job);

        // actualizar cursor
        final ms = job.sync.updatedAt.millisecondsSinceEpoch;
        if (ms > maxMs) maxMs = ms;
      }

      if (maxMs != lastMs) {
        await jobsRepo.setLastJobsSyncMs(maxMs);
      }
    } finally {
      _running = false;
    }
  }

  /// ✅ Sync completo (pull + push)
  Future<void> syncNow() async {
    await pull();
    await pushDirty();
  }
}