// lib/data/firestore/firestore_jobs_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:portones_mym/data/models/job_item.dart';

class FirestoreJobsDatasource {
  FirestoreJobsDatasource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('jobs');

  String? get _uid => _auth.currentUser?.uid;

  /// ✅ Stream (sin deleted)
  Stream<List<JobItem>> watchAllMine() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const Stream<List<JobItem>>.empty();

    final q = _col
        .where('ownerUid', isEqualTo: uid)
        .where('deleted', isEqualTo: false)
        .orderBy('fecha', descending: false);

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return JobItem.fromFirestore(data);
      }).toList();
    });
  }

  /// ✅ Stream (incluye deleted)
  Stream<List<JobItem>> watchAllMineIncludingDeleted() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const Stream<List<JobItem>>.empty();

    final q = _col
        .where('ownerUid', isEqualTo: uid)
        .orderBy('fecha', descending: false);

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return JobItem.fromFirestore(data);
      }).toList();
    });
  }

  // =========================================================
  // ✅ NUEVO: upsertJob (para SyncService)
  // =========================================================
  Future<void> upsertJob(JobItem job, {required String deviceId}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('No hay usuario logueado (ownerUid).');
    }

    // Asegurar que el doc tenga ownerUid
    final data = job.toFirestore(deviceId: deviceId);

    await _col.doc(job.id).set(
      data,
      SetOptions(merge: true),
    );
  }

  // =========================================================
  // ✅ NUEVO: fetchUpdatedSince (para SyncService)
  // =========================================================
  Future<List<JobItem>> fetchUpdatedSince(int lastSyncMs, {bool includeDeleted = true}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return [];

    Query<Map<String, dynamic>> q = _col
        .where('ownerUid', isEqualTo: uid)
        .where('updatedAtMs', isGreaterThan: lastSyncMs)
        .orderBy('updatedAtMs', descending: false);

    if (!includeDeleted) {
      q = q.where('deleted', isEqualTo: false);
    }

    final snap = await q.get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] ??= d.id;
      return JobItem.fromFirestore(data);
    }).toList();
  }
}