import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/user_routine.dart';

/// Elemento de `GET /users/me/routines` (HU-16):
/// `{ id, origin, name, coach_name, session_count }`.
abstract final class UserRoutineSummaryModel {
  static UserRoutineSummary fromJson(Map<String, dynamic> json) =>
      UserRoutineSummary(
        id: json['id'] as String,
        origin: RoutineOrigin.fromApi(json['origin'] as String),
        name: json['name'] as String,
        coachName: json['coach_name'] as String?,
        sessionCount: (json['session_count'] as num).toInt(),
      );
}

/// Respuesta de `POST /users/me/routines/recommended` (HU-15): la forma del
/// detalle más `objective`, `level` y `training_days`.
abstract final class RecommendedRoutineModel {
  static RecommendedRoutine fromJson(Map<String, dynamic> json) {
    final routine = UserRoutineModel.fromJson(json);
    return RecommendedRoutine(
      id: routine.id,
      name: routine.name,
      sessions: routine.sessions,
      objective: Objective.fromApi(json['objective'] as String),
      level: ExperienceLevel.fromApi(json['level'] as String),
      trainingDays: (json['training_days'] as num).toInt(),
    );
  }
}

/// Respuesta de `GET /routines/{id}` (HU-16):
/// `{ id, origin, name, coach_name?, sessions: [{ number, name, exercises }] }`.
abstract final class UserRoutineModel {
  static UserRoutine fromJson(Map<String, dynamic> json) => UserRoutine(
    id: json['id'] as String,
    origin: RoutineOrigin.fromApi(json['origin'] as String),
    name: json['name'] as String,
    coachName: json['coach_name'] as String?,
    sessions: [
      for (final item in json['sessions'] as List<dynamic>)
        _sessionFromJson(item as Map<String, dynamic>),
    ],
  );

  static RoutineSessionPlan _sessionFromJson(Map<String, dynamic> json) =>
      RoutineSessionPlan(
        number: (json['number'] as num).toInt(),
        name: json['name'] as String,
        exercises: [
          for (final item in json['exercises'] as List<dynamic>)
            _exerciseFromJson(item as Map<String, dynamic>),
        ],
      );

  static SessionExercise _exerciseFromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exercise_id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscle_group'] as String,
        sets: (json['sets'] as num).toInt(),
        reps: (json['reps'] as num).toInt(),
        restSeconds: (json['rest_seconds'] as num).toInt(),
      );
}
