class GarantiaItem {
  final String id;              // usaremos el mismo id del job para que sea fácil actualizar
  final String jobId;

  final String tituloTrabajo;
  final String? clientName;
  final String? phoneKey;       // tu clientPhoneKey (normalizado)
  final String? location;       // ubicacion snapshot del job
  final String provincia;       // calculada desde location

  final DateTime fechaTrabajo;  // fecha del job (día)
  final int months;             // 3/6/12/24
  final DateTime expiresAt;     // fecha de vencimiento

  final String? numeroGarantia; // No. de certificado (ej. "0101"), si ya se generó
  final String? pdfUrl;         // URL del certificado en Firebase Storage

  GarantiaItem({
    required this.id,
    required this.jobId,
    required this.tituloTrabajo,
    required this.fechaTrabajo,
    required this.months,
    required this.expiresAt,
    required this.provincia,
    this.clientName,
    this.phoneKey,
    this.location,
    this.numeroGarantia,
    this.pdfUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'jobId': jobId,
    'tituloTrabajo': tituloTrabajo,
    'clientName': clientName,
    'phoneKey': phoneKey,
    'location': location,
    'provincia': provincia,
    'fechaTrabajo': fechaTrabajo.toIso8601String(),
    'months': months,
    'expiresAt': expiresAt.toIso8601String(),
    'numeroGarantia': numeroGarantia,
    'pdfUrl': pdfUrl,
  };

  static GarantiaItem fromMap(Map map) => GarantiaItem(
    id: map['id'] as String,
    jobId: map['jobId'] as String,
    tituloTrabajo: map['tituloTrabajo'] as String,
    clientName: map['clientName'] as String?,
    phoneKey: map['phoneKey'] as String?,
    location: map['location'] as String?,
    provincia: (map['provincia'] as String?) ?? 'Sin ubicacion',
    fechaTrabajo: DateTime.parse(map['fechaTrabajo'] as String),
    months: (map['months'] as num).toInt(),
    expiresAt: DateTime.parse(map['expiresAt'] as String),
    numeroGarantia: map['numeroGarantia'] as String?,
    pdfUrl: map['pdfUrl'] as String?,
  );

  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return !exp.isAfter(today); // exp <= hoy
  }
}
