class ClientItem {
  final String id; // phoneKey como id
  final String nombre;
  final String telefonoRaw;
  final String telefonoKey;
  final String ubicacionTexto;

  ClientItem({
    required this.id,
    required this.nombre,
    required this.telefonoRaw,
    required this.telefonoKey,
    required this.ubicacionTexto,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'telefonoRaw': telefonoRaw,
    'telefonoKey': telefonoKey,
    'ubicacionTexto': ubicacionTexto,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  static ClientItem fromMap(Map map) => ClientItem(
    id: (map['id'] ?? '') as String,
    nombre: (map['nombre'] ?? '') as String,
    telefonoRaw: (map['telefonoRaw'] ?? '') as String,
    telefonoKey: (map['telefonoKey'] ?? '') as String,
    ubicacionTexto: (map['ubicacionTexto'] ?? '') as String,
  );
}