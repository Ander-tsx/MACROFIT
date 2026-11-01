import '../../domain/entities/routine.dart';

/// Respuesta de `/coach/routines` (HU-18): una rutina con sus ejercicios.
class RoutineModel extends Routine {
  const RoutineModel({
    required super.id,
    required super.name,
    required super.exercises,
    required super.createdAt,
    required super.updatedAt,
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) => RoutineModel(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises: [
      for (final item in json['exercises'] as List<dynamic>)
        _exerciseFromJson(item as Map<String, dynamic>),
    ],
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  static RoutineExercise _exerciseFromJson(Map<String, dynamic> json) =>
      RoutineExercise(
        exerciseId: json['exercise_id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscle_group'] as String,
        sets: (json['sets'] as num).toInt(),
        reps: (json['reps'] as num).toInt(),
        restSeconds: (json['rest_seconds'] as num).toInt(),
      );
}

/// Cuerpo de `POST /coach/routines` y `PUT /coach/routines/{id}`.
abstract final class RoutineDraftModel {
  static Map<String, dynamic> toJson(RoutineDraft draft) => {
    'name': draft.name,
    'exercises': [
      for (final exercise in draft.exercises)
        {
          'exercise_id': exercise.exerciseId,
          'sets': exercise.sets,
          'reps': exercise.reps,
          'rest_seconds': exercise.restSeconds,
        },
    ],
  };
}
