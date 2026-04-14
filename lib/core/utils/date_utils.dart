/// Convierte DateTime a string yyyy-MM-dd
String dayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Convierte yyyy-MM-dd a DateTime sin usar DateTime.parse()
/// (evita errores de formato)
DateTime dayKeyToDate(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid dayKey: $key');
  }

  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);

  return DateTime(y, m, d);
}

/// Devuelve solo la fecha sin hora
DateTime dayOnly(DateTime d) {
  return DateTime(d.year, d.month, d.day);
}

/// Suma meses y ajusta día final del mes
DateTime addMonthsClamped(DateTime d, int monthsToAdd) {
  final m = d.month + monthsToAdd;
  final newYear = d.year + ((m - 1) ~/ 12);
  final newMonth = ((m - 1) % 12) + 1;

  final lastDay = DateTime(newYear, newMonth + 1, 0).day;
  final newDay = d.day > lastDay ? lastDay : d.day;

  return DateTime(newYear, newMonth, newDay);
}