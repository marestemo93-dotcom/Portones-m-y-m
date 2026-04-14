// lib/core/sync/sync_meta.dart
class SyncMeta {
  final String deviceId; // id del dispositivo (persistente)
  final bool isDirty; // cambios locales pendientes
  final bool isDeleted; // soft delete
  final int version; // para conflictos
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const SyncMeta({
    required this.deviceId,
    required this.isDirty,
    required this.isDeleted,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSyncedAt,
  });

  /// ✅ Para datos viejos que no tienen sync:
  /// - isDirty=true para que al primer login se suba todo a Firestore
  /// - deviceId='legacy' (luego lo reemplazamos por el real)
  factory SyncMeta.legacy() {
    final now = DateTime.now();
    return SyncMeta(
      deviceId: 'legacy',
      isDirty: true,
      isDeleted: false,
      version: 0,
      createdAt: now,
      updatedAt: now,
      lastSyncedAt: null,
    );
  }

  /// ✅ Para crear metadata nueva local (primera vez en este dispositivo)
  /// - isDirty=true porque hay cambios locales que queremos subir al primer sync
  factory SyncMeta.fresh({required String deviceId}) {
    final now = DateTime.now();
    return SyncMeta(
      deviceId: deviceId,
      isDirty: true,
      isDeleted: false,
      version: 0,
      createdAt: now,
      updatedAt: now,
      lastSyncedAt: null,
    );
  }

  SyncMeta copyWith({
    String? deviceId,
    bool? isDirty,
    bool? isDeleted,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) {
    return SyncMeta(
      deviceId: deviceId ?? this.deviceId,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'isDirty': isDirty,
    'isDeleted': isDeleted,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  static SyncMeta fromMap(Map<String, dynamic> m) {
    DateTime parseOrNow(String k) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      return DateTime.now();
    }

    DateTime? parseNullable(String k) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      return null;
    }

    return SyncMeta(
      deviceId: (m['deviceId'] as String?) ?? 'legacy',
      isDirty: (m['isDirty'] as bool?) ?? true,
      isDeleted: (m['isDeleted'] as bool?) ?? false,
      version: (m['version'] as int?) ?? 0,
      createdAt: parseOrNow('createdAt'),
      updatedAt: parseOrNow('updatedAt'),
      lastSyncedAt: parseNullable('lastSyncedAt'),
    );
  }
}