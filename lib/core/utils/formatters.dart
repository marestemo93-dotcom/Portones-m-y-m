import 'package:intl/intl.dart';

String normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 8) return '506$digits';
  return digits;
}

String formatCrc(double v) {
  final f = NumberFormat.decimalPattern('es');
  return '₡${f.format(v.round())}';
}

String formatCrcCompact(double v) {
  final n = NumberFormat.compact(locale: 'es');
  return '₡${n.format(v)}';
}