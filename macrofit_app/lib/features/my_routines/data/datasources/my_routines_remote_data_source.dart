import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../../domain/entities/completed_session.dart';
import '../../domain/entities/user_routine.dart';
import '../models/completed_session_model.dart';
import '../models/user_routine_model.dart';

/// Endpoints de las rutinas del usuario (HU-15 y HU-16).
/// Usa el cliente HTTP **con** `AuthInterceptor`.
class MyRoutinesRemoteDataSource {
  const MyRoutinesRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-16 — `GET /users/me/routines`.
  Future<List<UserRoutineSummary>> getRoutines() => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>('/users/me/routines');
    return [
      for (final json in response.data!)
        UserRoutineSummaryModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-16 — `GET /routines/{id}`.
  Future<UserRoutine> getRoutine(String id) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/routines/$id');
    return UserRoutineModel.fromJson(response.data!);
  });

  /// HU-15 — `POST /users/me/routines/recommended` (`201`, sin cuerpo).
  Future<UserRoutine> requestRecommendedRoutine() => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/routines/recommended',
    );
    return UserRoutineModel.fromJson(response.data!);
  });

  /// HU-17 — `GET /users/me/routines/{id}/sessions`.
  Future<List<CompletedSession>> getCompletedSessions(String routineId) =>
      guardApiCall(() async {
        final response = await _dio.get<List<dynamic>>(
          '/users/me/routines/$routineId/sessions',
        );
        return [
          for (final json in response.data!)
            CompletedSessionModel.fromJson(json as Map<String, dynamic>),
        ];
      });

  /// HU-17 — `POST /users/me/routines/{id}/sessions` (`201`).
  Future<CompletedSession> completeSession(
    String routineId,
    int sessionNumber,
  ) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/routines/$routineId/sessions',
      data: CompletedSessionModel.requestJson(sessionNumber),
    );
    return CompletedSessionModel.fromJson(response.data!);
  });
}
