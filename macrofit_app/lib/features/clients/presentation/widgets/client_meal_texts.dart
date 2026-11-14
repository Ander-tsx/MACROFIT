/// Cantidad con a lo más un decimal: `413`, `42.2`.
String formatAmount(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// `413 kcal · P 42.2 g · G 4.9 g`.
String mealValuesText({
  required double calories,
  required double proteinG,
  required double fatG,
}) =>
    '${formatAmount(calories)} kcal · P ${formatAmount(proteinG)} g · '
    'G ${formatAmount(fatG)} g';

String _two(int value) => value.toString().padLeft(2, '0');

/// Hora local del registro: `19:30`.
String mealTimeText(DateTime eatenAt) {
  final local = eatenAt.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// Día elegido: `Hoy`, `Ayer` o `17/10/2026`.
String dayLabel(DateTime day, {required DateTime now}) {
  final date = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (today.difference(date).inDays) {
    0 => 'Hoy',
    1 => 'Ayer',
    _ => '${_two(date.day)}/${_two(date.month)}/${date.year}',
  };
}
