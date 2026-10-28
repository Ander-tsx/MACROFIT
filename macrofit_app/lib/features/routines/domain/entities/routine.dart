/// Ejercicio dentro de una rutina guardada (HU-18). `name` y `muscleGroup` son la
/// copia del catálogo que guarda el servidor.
class RoutineExercise {
  const RoutineExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String exerciseId;
  final String name;
  final String muscleGroup;
  final int sets;
  final int reps;
  final int restSeconds;

  @override
  bool operator ==(Object other) =>
      other is RoutineExercise &&
      other.exerciseId == exerciseId &&
      other.name == name &&
      other.muscleGroup == muscleGroup &&
      other.sets == sets &&
      other.reps == reps &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode =>
      Object.hash(exerciseId, name, muscleGroup, sets, reps, restSeconds);
}

/// Rutina personalizada de un coach (HU-18, RF-22).
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// En el orden en que se hacen.
  final List<RoutineExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Routine &&
      other.id == id &&
      other.name == name &&
      _sameList(other.exercises, exercises) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(exercises), createdAt, updatedAt);
}

/// Ejercicio que se manda al crear o editar una rutina.
class RoutineExerciseDraft {
  const RoutineExerciseDraft({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String exerciseId;
  final int sets;
  final int reps;
  final int restSeconds;

  @override
  bool operator ==(Object other) =>
      other is RoutineExerciseDraft &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.reps == reps &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode => Object.hash(exerciseId, sets, reps, restSeconds);
}

/// Cuerpo de `POST /coach/routines` y `PUT /coach/routines/{id}` (ya validado).
class RoutineDraft {
  const RoutineDraft({required this.name, required this.exercises});

  final String name;
  final List<RoutineExerciseDraft> exercises;

  @override
  bool operator ==(Object other) =>
      other is RoutineDraft &&
      other.name == name &&
      _sameList(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(exercises));
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
