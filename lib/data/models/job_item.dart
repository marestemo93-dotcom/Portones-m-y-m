import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/sync/sync_meta.dart';

/// Una línea de la tabla "Detalle del trabajo". Puede venir de un producto
/// del catálogo (productoId != null, precio no editable en la UI) o ser una
/// línea manual de texto libre (productoId == null).
class DetalleTrabajoLinea {
  final String? productoId;
  final String nombre;
  final String? categoria; // 'motor' / 'accesorio' / 'servicio', solo si viene de catálogo
  final double precio;
  final int cantidad;

  DetalleTrabajoLinea({
    this.productoId,
    required this.nombre,
    this.categoria,
    required this.precio,
    this.cantidad = 1,
  });

  double get total => precio * cantidad;

  Map<String, dynamic> toMap() => {
    'productoId': productoId,
    'nombre': nombre,
    'categoria': categoria,
    'precio': precio,
    'cantidad': cantidad,
  };

  static DetalleTrabajoLinea fromMap(Map map) => DetalleTrabajoLinea(
    productoId: map['productoId'] as String?,
    nombre: (map['nombre'] ?? '').toString(),
    categoria: map['categoria'] as String?,
    precio: (map['precio'] as num?)?.toDouble() ?? 0,
    cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
  );
}

/// 'trabajo' = flujo normal (con costo/productos). 'visita' = visita
/// técnica previa sin costo, para cotizar.
const String kTipoJobTrabajo = 'trabajo';
const String kTipoJobVisita = 'visita';

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
  final String? numeroGarantiaCertificado;

  final double? montoCrc;

  final List<DetalleTrabajoLinea> detalleTrabajo;
  final double? descuentoValor;
  final String? descuentoTipo; // 'monto' | 'porcentaje'

  final String tipo; // kTipoJobTrabajo | kTipoJobVisita
  final String? motivoVisita; // solo aplica si tipo == kTipoJobVisita

  /// Coordenadas recibidas por WhatsApp ([ubicacion:lat,lng] en el chat),
  /// asignadas automáticamente al job pendiente más cercano en fecha para
  /// ese cliente (ver server-bot.js). Habilitan el botón de Waze.
  final double? ubicacionLat;
  final double? ubicacionLng;

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
    this.numeroGarantiaCertificado,
    this.montoCrc,
    this.detalleTrabajo = const [],
    this.descuentoValor,
    this.descuentoTipo,
    this.tipo = kTipoJobTrabajo,
    this.motivoVisita,
    this.ubicacionLat,
    this.ubicacionLng,
    SyncMeta? sync,
  }) : sync = sync ?? SyncMeta.legacy();

  // =========================================================
  // UI HELPERS
  // =========================================================

  bool get esVisita => tipo == kTipoJobVisita;

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
    'numeroGarantiaCertificado': numeroGarantiaCertificado,
    'montoCrc': montoCrc,
    'detalleTrabajo': detalleTrabajo.map((d) => d.toMap()).toList(),
    'descuentoValor': descuentoValor,
    'descuentoTipo': descuentoTipo,
    'tipo': tipo,
    'motivoVisita': motivoVisita,
    'ubicacionLat': ubicacionLat,
    'ubicacionLng': ubicacionLng,
    'sync': sync.toMap(),
    'updatedAtMs': sync.updatedAt.millisecondsSinceEpoch,
    'createdAtMs': sync.createdAt.millisecondsSinceEpoch,
    'deleted': sync.isDeleted,
  };

  static List<DetalleTrabajoLinea> _parseDetalle(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Object>()
        .map((e) => DetalleTrabajoLinea.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static JobItem fromMap(Map map) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.parse(v.toString());
    }

    int? parseTimeMinutes(dynamic v) {
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
      fecha: parseFecha(map['fecha']),
      timeMinutes: parseTimeMinutes(map['timeMinutes']),
      clientPhoneKey: map['clientPhoneKey'] as String?,
      clientNameSnapshot: map['clientNameSnapshot'] as String?,
      locationSnapshot: map['locationSnapshot'] as String?,
      isDone: (map['isDone'] as bool?) ?? false,
      doneAtIso: map['doneAtIso'] as String?,
      nextVisitIso: map['nextVisitIso'] as String?,
      numeroGarantiaCertificado: map['numeroGarantiaCertificado'] as String?,
      montoCrc: (map['montoCrc'] as num?)?.toDouble(),
      detalleTrabajo: _parseDetalle(map['detalleTrabajo']),
      descuentoValor: (map['descuentoValor'] as num?)?.toDouble(),
      descuentoTipo: map['descuentoTipo'] as String?,
      tipo: (map['tipo'] as String?) ?? kTipoJobTrabajo,
      motivoVisita: map['motivoVisita'] as String?,
      ubicacionLat: (map['ubicacionLat'] as num?)?.toDouble(),
      ubicacionLng: (map['ubicacionLng'] as num?)?.toDouble(),
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
      'numeroGarantiaCertificado': numeroGarantiaCertificado,
      'montoCrc': montoCrc,
      'detalleTrabajo': detalleTrabajo.map((d) => d.toMap()).toList(),
      'descuentoValor': descuentoValor,
      'descuentoTipo': descuentoTipo,
      'tipo': tipo,
      'motivoVisita': motivoVisita,
      'ubicacionLat': ubicacionLat,
      'ubicacionLng': ubicacionLng,
      'deviceId': deviceId,
      'sync': sync.toMap(),
      'updatedAtMs': sync.updatedAt.millisecondsSinceEpoch,
      'createdAtMs': sync.createdAt.millisecondsSinceEpoch,
      'deleted': sync.isDeleted,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  static JobItem fromFirestore(Map<String, dynamic> map) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    int? parseTimeMinutes(dynamic v) {
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
      fecha: parseFecha(map['fecha']),
      timeMinutes: parseTimeMinutes(map['timeMinutes']),
      clientPhoneKey: map['clientPhoneKey'] as String?,
      clientNameSnapshot: map['clientNameSnapshot'] as String?,
      locationSnapshot: map['locationSnapshot'] as String?,
      isDone: (map['isDone'] as bool?) ?? false,
      doneAtIso: map['doneAtIso'] as String?,
      nextVisitIso: map['nextVisitIso'] as String?,
      numeroGarantiaCertificado: map['numeroGarantiaCertificado'] as String?,
      montoCrc: (map['montoCrc'] as num?)?.toDouble(),
      detalleTrabajo: _parseDetalle(map['detalleTrabajo']),
      descuentoValor: (map['descuentoValor'] as num?)?.toDouble(),
      descuentoTipo: map['descuentoTipo'] as String?,
      tipo: (map['tipo'] as String?) ?? kTipoJobTrabajo,
      motivoVisita: map['motivoVisita'] as String?,
      ubicacionLat: (map['ubicacionLat'] as num?)?.toDouble(),
      ubicacionLng: (map['ubicacionLng'] as num?)?.toDouble(),
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
      numeroGarantiaCertificado: numeroGarantiaCertificado,
      montoCrc: montoCrc,
      detalleTrabajo: detalleTrabajo,
      descuentoValor: descuentoValor,
      descuentoTipo: descuentoTipo,
      tipo: tipo,
      motivoVisita: motivoVisita,
      ubicacionLat: ubicacionLat,
      ubicacionLng: ubicacionLng,
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
      numeroGarantiaCertificado: numeroGarantiaCertificado,
      montoCrc: montoCrc,
      detalleTrabajo: detalleTrabajo,
      descuentoValor: descuentoValor,
      descuentoTipo: descuentoTipo,
      tipo: tipo,
      motivoVisita: motivoVisita,
      ubicacionLat: ubicacionLat,
      ubicacionLng: ubicacionLng,
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
