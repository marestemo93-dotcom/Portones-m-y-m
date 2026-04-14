// lib/core/sync/realtime_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/data/firestore/firestore_jobs_datasource.dart';
import 'package:portones_mym/core/sync/jobs_realtime_listener.dart';

final firestoreJobsDatasourceProvider = Provider<FirestoreJobsDatasource>((ref) {
  return FirestoreJobsDatasource();
});

final jobsRealtimeListenerProvider = Provider<JobsRealtimeListener>((ref) {
  final remote = ref.watch(firestoreJobsDatasourceProvider);
  final local = ref.watch(jobsRepoProvider); // ✅ el tuyo (NO duplicado)
  return JobsRealtimeListener(remote: remote, local: local);
});

/// ✅ Provider “side-effect” que arranca el stream realtime.
/// Con que se haga `ref.watch(jobsRealtimeStarterProvider)` 1 vez, queda activo.
final jobsRealtimeStarterProvider = Provider<void>((ref) {
  final listener = ref.watch(jobsRealtimeListenerProvider);
  listener.start();

  ref.onDispose(() {
    listener.stop();
  });
});