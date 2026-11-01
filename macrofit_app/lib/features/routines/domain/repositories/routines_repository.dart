import '../entities/exercise.dart';
import '../entities/routine.dart';

/// Rutinas del coach de la sesión (HU-18) y catálogo de ejercicios (TEC-09).
/// Los métodos lanzan `ApiException` ante errores de la API o de red
/// (p. ej. `VALIDATION_ERROR`, `ROUTINE_NOT_FOUND`).
abstract interface class RoutinesRepository {
  /// `GET /exercises`, filtrado en el servidor por grupo muscular y nivel
  /// (`null` = sin filtro).
  Future<List<Exercise>> getExercises({
    MuscleGroup? muscleGroup,
    ExerciseLevel? level,
  });

  /// `GET /coach/routines`: la editada más recientemente primero.
  Future<List<Routine>> getRoutines();

  /// `POST /coach/routines`.
  Future<Routine> createRoutine(RoutineDraft draft);

  /// `PUT /coach/routines/{id}`: reemplaza nombre y ejercicios.
  Future<Routine> updateRoutine(String id, RoutineDraft draft);

  /// `DELETE /coach/routines/{id}`.
  Future<void> deleteRoutine(String id);
}
