import '../entities/completed_session.dart';
import '../entities/user_routine.dart';

/// Rutinas del usuario: recomendada (HU-15) y asignadas por su coach (HU-19).
abstract interface class MyRoutinesRepository {
  /// HU-16 — recomendada vigente y asignadas activas.
  Future<List<UserRoutineSummary>> getRoutines();

  /// HU-16 — detalle con sesiones y ejercicios. `ROUTINE_NOT_FOUND` si ya no
  /// es accesible (retirada, reemplazada o ajena).
  Future<UserRoutine> getRoutine(String id);

  /// HU-15 — genera la rutina recomendada y reemplaza la vigente.
  /// `PROFILE_NOT_FOUND` sin perfil; `EXERCISE_CATALOG_INCOMPLETE` si el catálogo
  /// no alcanza para generarla.
  Future<RecommendedRoutine> requestRecommendedRoutine();

  /// HU-17 — sesiones completadas de la rutina, la más reciente primero.
  Future<List<CompletedSession>> getCompletedSessions(String routineId);

  /// HU-17 — marca hoy como completada la sesión [sessionNumber].
  /// `SESSION_ALREADY_COMPLETED` si ya se registró hoy; `ROUTINE_NOT_FOUND` si
  /// la rutina ya no está disponible.
  Future<CompletedSession> completeSession(String routineId, int sessionNumber);
}
