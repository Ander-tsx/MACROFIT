import '../entities/exercise.dart';
import '../entities/routine.dart';
import '../entities/routine_assignment.dart';

/// Rutinas del coach de la sesión (HU-18), su asignación a clientes (HU-19) y
/// catálogo de ejercicios (TEC-09). Los métodos lanzan `ApiException` ante
/// errores de la API o de red (p. ej. `VALIDATION_ERROR`, `ROUTINE_NOT_FOUND`,
/// `CLIENT_NOT_LINKED`).
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

  /// HU-19 — `GET /coach/routines/{id}/assignments`: asignaciones activas de
  /// clientes que siguen vinculados, la más reciente primero.
  Future<List<RoutineAssignment>> getAssignments(String routineId);

  /// HU-19 — `POST /coach/routines/{id}/assignments`: asigna la rutina a
  /// [clientIds] (todo o nada). Devuelve la asignación de cada cliente pedido,
  /// en el mismo orden. Un cliente sin vinculación activa lanza
  /// `CLIENT_NOT_LINKED` con `fields["client_ids[i]"]`.
  Future<List<RoutineAssignment>> assignRoutine(
    String routineId,
    List<String> clientIds,
  );

  /// HU-20 — `DELETE /coach/routines/{id}/assignments/{clientId}` (`204`):
  /// retira la rutina del cliente. Sus sesiones completadas se conservan.
  /// `ASSIGNMENT_NOT_FOUND` si ya estaba retirada; `ROUTINE_NOT_FOUND` si la
  /// rutina no es del coach.
  Future<void> removeAssignment(String routineId, String clientId);
}
