import '../../../summary/domain/entities/macro_values.dart';

/// HU-22 — series de progreso del usuario en un periodo (`GET /users/me/progress`):
/// peso, calorías y macros por día contra la meta, y cumplimiento de sesiones
/// por semana (RF-18).
class ProgressReport {
  const ProgressReport({
    required this.from,
    required this.to,
    required this.weights,
    required this.days,
    required this.compliance,
  });

  /// Primer y último día del periodo, `YYYY-MM-DD`.
  final String from;
  final String to;

  /// Pesos del periodo en orden cronológico.
  final List<WeightPoint> weights;

  /// Un elemento por día del periodo; los días sin registros traen consumo en 0.
  final List<ProgressDay> days;

  /// Sesiones completadas contra las planeadas, por semana.
  final List<WeeklyCompliance> compliance;

  /// La tendencia de peso necesita al menos dos registros.
  bool get hasWeightTrend => weights.length >= 2;

  /// Hay al menos un día con comida registrada.
  bool get hasMeals => days.any((day) => !day.consumed.isZero);

  /// Hay semanas con sesiones planeadas (el perfil tiene días de entrenamiento).
  bool get hasCompliance => compliance.any((week) => week.plannedSessions > 0);
}

/// Un registro de peso.
class WeightPoint {
  const WeightPoint({required this.recordedAt, required this.weightKg});

  final DateTime recordedAt;
  final double weightKg;
}

/// Un día: lo consumido contra la meta vigente ese día.
class ProgressDay {
  const ProgressDay({
    required this.date,
    required this.goal,
    required this.consumed,
    required this.goalMet,
  });

  /// `YYYY-MM-DD`.
  final String date;

  /// Meta vigente ese día; `null` si todavía no había una.
  final MacroValues? goal;
  final MacroValues consumed;

  /// Calorías entre el 90 % y el 110 % de la meta (misma regla que HU-11).
  final bool goalMet;
}

/// Cumplimiento de entrenamiento de una semana del periodo.
class WeeklyCompliance {
  const WeeklyCompliance({
    required this.weekStart,
    required this.weekEnd,
    required this.completedSessions,
    required this.plannedSessions,
  });

  /// Primer y último día de la semana dentro del periodo, `YYYY-MM-DD`.
  final String weekStart;
  final String weekEnd;
  final int completedSessions;

  /// Días de entrenamiento del perfil en esa semana.
  final int plannedSessions;
}

extension on MacroValues {
  bool get isZero => caloriesKcal == 0 && proteinG == 0 && fatG == 0;
}
