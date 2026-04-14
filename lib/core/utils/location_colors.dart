import 'package:flutter/material.dart';

Color colorForLocation(String? location) {
  final loc = (location ?? '').trim().toLowerCase();

  if (loc.isEmpty) return Colors.grey;

  if (loc.contains('cartago')) return Colors.blue;
  if (loc.contains('san jose') || loc.contains('san josé')) return Colors.purple;
  if (loc.contains('heredia')) return Colors.yellow;
  if (loc.contains('alajuela')) return Colors.red;
  if (loc.contains('limon') || loc.contains('limón')) return Colors.green;
  if (loc.contains('guanacaste')) return Colors.white;
  if (loc.contains('puntarenas')) return Colors.brown;

  return Colors.grey;
}