import 'day_summary.dart';
import 'macro_values.dart';

/// Resumen de 7 días (HU-11).
class WeekSummary {
  const WeekSummary({
    required this.start,
    required this.end,
    required this.days,
    required this.average,
    required this.goalMetDays,
  });

  /// Primer y último día, `YYYY-MM-DD`.
  final String start;
  final String end;

  /// Siempre 7, del primero al último; un día sin registros trae consumo en 0.
  final List<DaySummary> days;

  /// Total de los 7 días entre 7 (los días sin registros cuentan como 0).
  final MacroValues average;

  /// Cuántos de los 7 días cumplieron la meta de calorías.
  final int goalMetDays;
}
