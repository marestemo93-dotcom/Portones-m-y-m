import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/firestore/firestore_jobs_datasource.dart';
import '../../data/repositories/jobs_repository.dart';
import '../../data/models/job_item.dart';

class JobsRealtimeListener {
  JobsRealtimeListener({
    required FirestoreJobsDatasource remote,
    required JobsRepository local,
  })  : _remote = remote,
        _local = local;

  final FirestoreJobsDatasource _remote;
  final JobsRepository _local;

  StreamSubscription<List<JobItem>>? _sub;

  void start() {
    if (_sub != null) return;

    _sub = _remote.watchAllMineIncludingDeleted().listen(
          (jobs) async {
        debugPrint('📡 Firestore snapshot jobs=${jobs.length}');
        for (final job in jobs) {
          debugPrint('➡️ apply job ${job.id} ${job.titulo} deleted=${job.sync.isDeleted}');
          await _local.upsertFromRemote(job);
        }
        debugPrint('✅ applied snapshot to Hive');
      },
      onError: (e, st) {
        debugPrint('❌ Realtime listener error: $e');
        debugPrint('$st');
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}