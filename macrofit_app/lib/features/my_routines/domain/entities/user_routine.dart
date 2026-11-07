/// Origen de una rutina del usuario (RN-08).
enum RoutineOrigin {
  /// Recomendada por el sistema (HU-15).
  system('system'),

  /// Asignada por un coach (HU-19).
  coach('coach');

  const RoutineOrigin(this.apiValue);

  final String apiValue;

  /// Un valor desconocido se trata como recomendada.
  static RoutineOrigin fromApi(String value) =>
      value == coach.apiValue ? coach : system;
}

/// Rutina en la lista «Mis rutinas» (HU-16).
class UserRoutineSummary {
  const UserRoutineSummary({
    required this.id,
    required this.origin,
    required this.name,
    required this.sessionCount,
    this.coachName,
  });

  final String id;
  final RoutineOrigin origin;
  final String name;

  /// Solo en las asignadas.
  final String? coachName;
  final int sessionCount;

  @override
  bool operator ==(Object other) =>
      other is UserRoutineSummary &&
      other.id == id &&
      other.origin == origin &&
      other.name == name &&
      other.coachName == coachName &&
      other.sessionCount == sessionCount;

  @override
  int get hashCode => Object.hash(id, origin, name, coachName, sessionCount);
}

/// Detalle de una rutina del usuario con sus sesiones (HU-16).
class UserRoutine {
  const UserRoutine({
    required this.id,
    required this.origin,
    required this.name,
    required this.sessions,
    this.coachName,
  });

  final String id;
  final RoutineOrigin origin;
  final String name;
  final String? coachName;

  /// Numeradas desde 1. Una rutina asignada tiene una sola.
  final List<RoutineSessionPlan> sessions;

  UserRoutineSummary toSummary() => UserRoutineSummary(
    id: id,
    origin: origin,
    name: name,
    coachName: coachName,
    sessionCount: sessions.length,
  );
}

/// Sesión de una rutina («Día 1 · Empuje»).
class RoutineSessionPlan {
  const RoutineSessionPlan({
    required this.number,
    required this.name,
    required this.exercises,
  });

  final int number;
  final String name;
  final List<SessionExercise> exercises;
}

/// Ejercicio de una sesión con su volumen.
class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String exerciseId;
  final String name;

  /// Valor de la API (`chest`, `back`…).
  final String muscleGroup;
  final int sets;
  final int reps;
  final int restSeconds;
}
