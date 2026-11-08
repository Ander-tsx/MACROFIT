import '../../domain/entities/user_routine.dart';

/// Etiqueta de origen (RN-08): «Recomendada» o «Asignada por» y el nombre del coach.
String originLabel(RoutineOrigin origin, String? coachName) => switch (origin) {
  RoutineOrigin.system => 'Recomendada',
  RoutineOrigin.coach => switch (coachName?.trim()) {
    final name? when name.isNotEmpty => 'Asignada por $name',
    _ => 'Asignada por tu coach',
  },
};

/// «1 sesión» / «3 sesiones».
String sessionCountText(int count) =>
    count == 1 ? '1 sesión' : '$count sesiones';

/// «3 series × 10 reps · 60 s de descanso».
String exerciseVolumeText(SessionExercise exercise) {
  final sets = exercise.sets == 1 ? '1 serie' : '${exercise.sets} series';
  return '$sets × ${exercise.reps} reps · ${exercise.restSeconds} s de descanso';
}

/// Grupo muscular en español; un valor desconocido se muestra tal cual.
String muscleGroupText(String apiValue) => switch (apiValue) {
  'chest' => 'Pecho',
  'back' => 'Espalda',
  'legs' => 'Piernas',
  'shoulders' => 'Hombros',
  'arms' => 'Brazos',
  'core' => 'Core',
  _ => apiValue,
};
