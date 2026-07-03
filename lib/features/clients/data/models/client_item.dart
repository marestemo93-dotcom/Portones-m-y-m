class ClientItem {
  final String id;
  final String nombre;
  final String telefonoRaw;
  final String telefonoKey;
  final String ubicacionTexto;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientItem({
    required this.id,
    required this.nombre,
    required this.telefonoRaw,
    required this.telefonoKey,
    required this.ubicacionTexto,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'telefonoRaw': telefonoRaw,
    'telefonoKey': telefonoKey,
    'ubicacionTexto': ubicacionTexto,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ClientItem fromMap(Map map) {
    DateTime parseOrNow(String key) {
      final v = map[key];
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) {}
      }
      return DateTime.now();
    }

    return ClientItem(
      id: (map['id'] ?? '') as String,
      nombre: (map['nombre'] ?? '') as String,
      telefonoRaw: (map['telefonoRaw'] ?? '') as String,
      telefonoKey: (map['telefonoKey'] ?? '') as String,
      ubicacionTexto: (map['ubicacionTexto'] ?? '') as String,
      createdAt: parseOrNow('createdAt'),
      updatedAt: parseOrNow('updatedAt'),
    );
  }
}