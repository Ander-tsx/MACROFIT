import '../../../goals/domain/entities/nutritional_goal.dart';
import 'macro_values.dart';

/// Resumen de un día (HU-10): consumo, meta vigente ese día y lo que falta.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.goalSource,
    required this.goal,
    required this.consumed,
    required this.remaining,
    this.goalMet = false,
  });

  /// `YYYY-MM-DD` en la zona horaria de la app.
  final String date;
  final GoalSource goalSource;
  final MacroValues goal;
  final MacroValues consumed;

  /// Meta − consumo. Es negativo cuando el consumo supera la meta.
  final MacroValues remaining;

  /// HU-11 — el día consumió calorías y quedaron entre el 90 % y el 110 % de la meta.
  /// El resumen diario (HU-10) no lo trae y queda en `false`.
  final bool goalMet;
}
