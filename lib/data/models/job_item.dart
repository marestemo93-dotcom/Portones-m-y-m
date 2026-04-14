import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/sync/sync_meta.dart';

class JobItem {
  final String id;
  final String titulo;
  final DateTime fecha; // solo día
  final int? timeMinutes; // minutos desde 00:00
  final String? clientPhoneKey;
  final String? clientNameSnapshot;
  final String? locationSnapshot;

  final bool isDone;
  final String? doneAtIso;
  final String? nextVisitIso;

  final double? montoCrc;

  /// Metadata de sincronización
  final SyncMeta sync;

  JobItem({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.timeMinutes,
    this.clientPhoneKey,
    this.clientNameSnapshot,
    this.locationSnapshot,
    this.isDone = false,
    this.doneAtIso,
    this.nextVisitIso,
    this.montoCrc,
    SyncMeta? sync,
  }) : sync = sync ?? SyncMeta.legacy();

  // =========================================================
  // UI HELPERS
  // =========================================================

  TimeOfDay? get timeOfDay {
    if (timeMinutes == null) return null;
    final h = timeMinutes! ~/ 60;
    final m = timeMinutes! % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  DateTime? get nextVisitDate {
    if (nextVisitIso == null || nextVisitIso!.isEmpty) return null;
    try {
      return DateTime.parse(nextVisitIso!);
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // HIVE / LOCAL MAP
  // =========================================================

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'fecha': fecha.toIso8601String(),
    'timeMinutes': timeMinutes,
    'clientPhoneKey': clientPhoneKey,
    'clientNameSnapshot': clientNameSnapshot,
    'locationSnapshot': locationSnapshot,
    'isDone': isDone,
    'doneAtIso': doneAtIso,
    'nextVisitIso': nextVisitIso,
    'montoCrc': montoCrc,
    'sync': sync.toMap(),
    'updatedAtMs': sync.updatedAt.millisecondsSinceEpoch,
    'createdAtMs': sync.createdAt.millisecondsSinceEpoch,
    'deleted': sync.isDeleted,
  };

  static JobItem fromMap(Map map) {
    DateTime _parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.parse(v.toString());
    }

    int? _parseTimeMinutes(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final syncMap = map['sync'];
    final parsedSync = (syncMap is Map)
        ? SyncMeta.fromMap(syncMap.cast<String, dynamic>())
        : SyncMeta.legacy();

    return JobItem(
      id: (map['id'] ?? '').toString(),
      titulo: (map['titulo'] ?? '').toString(),
      fecha: _parseFecha(map['fecha']),
      timeMinutes: _parseTimeMinutes(map['timeMinutes']),
      clientPhoneKey: map['clientPhoneKey'] as String?,
      clientNameSnapshot: map['clientNameSnapshot'] as String?,
      locationSnapshot: map['locationSnapshot'] as String?,
      isDone: (map['isDone'] as bool?) ?? false,
      doneAtIso: map['doneAtIso'] as String?,
      nextVisitIso: map['nextVisitIso'] as String?,
      montoCrc: (map['montoCrc'] as num?)?.toDouble(),
      sync: parsedSync,
    );
  }

  // =========================================================
  // FIRESTORE (NUEVO)
  // =========================================================

  Map<String, dynamic> toFirestore({required String deviceId}) {
    return {
      'id': id,
      'titulo': titulo,
      'fecha': Timestamp.fromDate(
        DateTime(fecha.year, fecha.month, fecha.day),
      ),
      'timeMinutes': timeMinutes,
      'clientPhoneKey': clientPhoneKey,
      'clientNameSnapshot': clientNameSnapshot,
      'locationSnapshot': locationSnapshot,
      'isDone': isDone,
      'doneAtIso': doneAtIso,
      'nextVisitIso': nextVisitIso,
      'montoCrc': montoCrc,
      'deviceId': deviceId,
      'sync': sync.toMap(),
      'updatedAtMs': sync.updatedAt.millisecondsSinceEpoch,
      'createdAtMs': sync.createdAt.millisecondsSinceEpoch,
      'deleted': sync.isDeleted,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  static JobItem fromFirestore(Map<String, dynamic> map) {
    DateTime _parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    int? _parseTimeMinutes(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final syncMap = map['sync'];
    final parsedSync = (syncMap is Map)
        ? SyncMeta.fromMap(Map<String, dynamic>.from(syncMap))
        : SyncMeta.legacy();

    return JobItem(
      id: (map['id'] ?? '').toString(),
      titulo: (map['titulo'] ?? '').toString(),
      fecha: _parseFecha(map['fecha']),
      timeMinutes: _parseTimeMinutes(map['timeMinutes']),
      clientPhoneKey: map['clientPhoneKey'] as String?,
      clientNameSnapshot: map['clientNameSnapshot'] as String?,
      locationSnapshot: map['locationSnapshot'] as String?,
      isDone: (map['isDone'] as bool?) ?? false,
      doneAtIso: map['doneAtIso'] as String?,
      nextVisitIso: map['nextVisitIso'] as String?,
      montoCrc: (map['montoCrc'] as num?)?.toDouble(),
      sync: parsedSync,
    );
  }

  // =========================================================
  // SYNC HELPERS
  // =========================================================

  JobItem markDirty({String? deviceId}) {
    final now = DateTime.now();
    return JobItem(
      id: id,
      titulo: titulo,
      fecha: fecha,
      timeMinutes: timeMinutes,
      clientPhoneKey: clientPhoneKey,
      clientNameSnapshot: clientNameSnapshot,
      locationSnapshot: locationSnapshot,
      isDone: isDone,
      doneAtIso: doneAtIso,
      nextVisitIso: nextVisitIso,
      montoCrc: montoCrc,
      sync: sync.copyWith(
        deviceId: deviceId ?? sync.deviceId,
        isDirty: true,
        updatedAt: now,
        version: sync.version + 1,
      ),
    );
  }

  JobItem markDeleted({String? deviceId}) {
    final now = DateTime.now();
    return JobItem(
      id: id,
      titulo: titulo,
      fecha: fecha,
      timeMinutes: timeMinutes,
      clientPhoneKey: clientPhoneKey,
      clientNameSnapshot: clientNameSnapshot,
      locationSnapshot: locationSnapshot,
      isDone: isDone,
      doneAtIso: doneAtIso,
      nextVisitIso: nextVisitIso,
      montoCrc: montoCrc,
      sync: sync.copyWith(
        deviceId: deviceId ?? sync.deviceId,
        isDeleted: true,
        isDirty: true,
        updatedAt: now,
        version: sync.version + 1,
      ),
    );
  }
}