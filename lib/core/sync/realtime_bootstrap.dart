import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:portones_mym/data/firestore/firestore_jobs_datasource.dart';
import 'package:portones_mym/data/repositories/jobs_repository.dart';
import 'package:portones_mym/core/sync/jobs_realtime_listener.dart';

class RealtimeBootstrap {
  RealtimeBootstrap({
    required FirestoreJobsDatasource remote,
    required JobsRepository local,
  })  : _remote = remote,
        _local = local;

  final FirestoreJobsDatasource _remote;
  final JobsRepository _local;

  JobsRealtimeListener? _listener;
  StreamSubscription<User?>? _authSub;

  void start() {
    if (_authSub != null) return;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      debugPrint('🔐 authState uid=$uid');

      if (user == null) {
        _listener?.stop();
        _listener = null;
        return;
      }

      _listener ??= JobsRealtimeListener(remote: _remote, local: _local);
      _listener!.start();
    }, onError: (e, st) {
      debugPrint('❌ authStateChanges error: $e');
      debugPrint('$st');
    });
  }

  Future<void> stop() async {
    await _authSub?.cancel();
    _authSub = null;

    await _listener?.stop();
    _listener = null;
  }
}