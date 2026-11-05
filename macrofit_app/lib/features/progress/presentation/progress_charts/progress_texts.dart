import '../../../summary/domain/usecases/app_day.dart';
import '../../domain/entities/progress_period.dart';

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// `4 nov` de un día `YYYY-MM-DD`.
String shortDate(String day) =>
    '${dayOfMonth(day)} ${_months[monthOf(day) - 1].substring(0, 3)}';

/// Etiqueta del periodo: `29 oct – 4 nov` o `noviembre 2026`.
String periodLabel(ProgressPeriod period) => switch (period.range) {
  ProgressRange.week => '${shortDate(period.from)} – ${shortDate(period.to)}',
  ProgressRange.month =>
    '${_months[monthOf(period.from) - 1]} ${period.from.substring(0, 4)}',
};

/// Etiqueta del eje de un día: el día de la semana en una semana (`lun`) y el
/// número del día en un mes (`4`).
String dayAxisLabel(String day, ProgressRange range) => switch (range) {
  ProgressRange.week => _weekdays[weekdayOf(day) - 1],
  ProgressRange.month => '${dayOfMonth(day)}',
};

/// Número sin decimales sobrantes: `70` y `35.5`.
String number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// Diferencia de peso del periodo: `−0.7 kg`, `+1.2 kg` o `Sin cambio`.
String weightChangeText(double first, double last) {
  final delta = last - first;
  if (delta.abs() < 0.05) return 'Sin cambio';
  final sign = delta > 0 ? '+' : '−';
  return '$sign${delta.abs().toStringAsFixed(1)} kg en el periodo';
}

/// Un macro está dentro de la meta si queda entre el 90 % y el 110 % (la misma
/// regla que usa la app para las calorías, HU-11).
bool withinGoal(double consumed, double? goal) =>
    goal != null &&
    goal > 0 &&
    consumed > 0 &&
    consumed >= goal * 0.9 &&
    consumed <= goal * 1.1;
