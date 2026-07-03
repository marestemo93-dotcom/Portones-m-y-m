import 'package:flutter/material.dart';

const List<String> kProvinceOrder = [
  'Cartago',
  'San Jose',
  'Heredia',
  'Alajuela',
  'Guanacaste',
  'Puntarenas',
  'Limon',
  'Sin ubicacion',
];

String provinciaFromUbic(String? location) {
  final loc = (location ?? '').trim().toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  if (loc.isEmpty) return 'Sin ubicacion';
  if (loc.contains('cartago')) return 'Cartago';
  if (loc.contains('san jose') || loc.contains('sanjose')) return 'San Jose';
  if (loc.contains('heredia')) return 'Heredia';
  if (loc.contains('alajuela')) return 'Alajuela';
  if (loc.contains('guanacaste')) return 'Guanacaste';
  if (loc.contains('puntarenas')) return 'Puntarenas';
  if (loc.contains('limon')) return 'Limon';

  return 'Sin ubicacion';
}

Color colorForLocation(String? location) {
  return colorForProvincia(provinciaFromUbic(location));
}

Color colorForProvincia(String prov) {
  switch (prov) {
    case 'Cartago': return Colors.blue;
    case 'San Jose': return Colors.purple;
    case 'Heredia': return Colors.yellow;
    case 'Alajuela': return Colors.red;
    case 'Limon': return Colors.green;
    case 'Guanacaste': return Colors.white;
    case 'Puntarenas': return Colors.brown;
    default: return Colors.grey;
  }
}