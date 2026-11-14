import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../models/exercise_model.dart';
import '../models/routine_assignment_model.dart';
import '../models/routine_model.dart';

/// Endpoints de rutinas del coach (HU-18), su asignación (HU-19) y del catálogo
/// de ejercicios (TEC-09).
/// Usa el cliente HTTP **con** `AuthInterceptor`.
class RoutinesRemoteDataSource {
  const RoutinesRemoteDataSource(this._dio);

  final Dio _dio;

  static const _routines = '/coach/routines';

  /// TEC-09 — `GET /exercises?muscle_group=&level=` (filtros opcionales).
  Future<List<ExerciseModel>> getExercises({
    MuscleGroup? muscleGroup,
    ExerciseLevel? level,
  }) => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      '/exercises',
      queryParameters: {
        'muscle_group': ?muscleGroup?.apiValue,
        'level': ?level?.apiValue,
      },
    );
    return [
      for (final json in response.data!)
        ExerciseModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-18 — `GET /coach/routines`.
  Future<List<RoutineModel>> getRoutines() => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>(_routines);
    return [
      for (final json in response.data!)
        RoutineModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-18 — `POST /coach/routines` (`201`).
  Future<RoutineModel> createRoutine(RoutineDraft draft) =>
      guardApiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          _routines,
          data: RoutineDraftModel.toJson(draft),
        );
        return RoutineModel.fromJson(response.data!);
      });

  /// HU-18 — `PUT /coach/routines/{id}` (`200`).
  Future<RoutineModel> updateRoutine(String id, RoutineDraft draft) =>
      guardApiCall(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '$_routines/$id',
          data: RoutineDraftModel.toJson(draft),
        );
        return RoutineModel.fromJson(response.data!);
      });

  /// HU-18 — `DELETE /coach/routines/{id}` (`204` sin cuerpo).
  Future<void> deleteRoutine(String id) => guardApiCall(() async {
    await _dio.delete<void>('$_routines/$id');
  });

  /// HU-19 — `GET /coach/routines/{id}/assignments`.
  Future<List<RoutineAssignmentModel>> getAssignments(String routineId) =>
      guardApiCall(() async {
        final response = await _dio.get<List<dynamic>>(
          '$_routines/$routineId/assignments',
        );
        return [
          for (final json in response.data!)
            RoutineAssignmentModel.fromJson(json as Map<String, dynamic>),
        ];
      });

  /// HU-19 — `POST /coach/routines/{id}/assignments` (`201`).
  Future<List<RoutineAssignmentModel>> assignRoutine(
    String routineId,
    List<String> clientIds,
  ) => guardApiCall(() async {
    final response = await _dio.post<List<dynamic>>(
      '$_routines/$routineId/assignments',
      data: AssignRoutineRequestModel.toJson(clientIds),
    );
    return [
      for (final json in response.data!)
        RoutineAssignmentModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-20 — `DELETE /coach/routines/{id}/assignments/{clientId}` (`204`).
  Future<void> removeAssignment(String routineId, String clientId) =>
      guardApiCall(() async {
        await _dio.delete<void>('$_routines/$routineId/assignments/$clientId');
      });
}
