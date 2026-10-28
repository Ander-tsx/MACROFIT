import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/coach_client_model.dart';
import '../models/goal_model.dart';

/// Endpoints de metas (HU-04 y HU-05). Usa el cliente HTTP **con** `AuthInterceptor`.
class GoalsRemoteDataSource {
  const GoalsRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-04 — `GET /users/me/goals/current`.
  Future<GoalModel> getCurrentGoal() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/me/goals/current',
    );
    return GoalModel.fromJson(response.data!);
  });

  /// HU-04 — `GET /users/me/goals`.
  Future<List<GoalModel>> getGoalsHistory() => _getGoals('/users/me/goals');

  /// HU-05 — `GET /coach/clients`.
  Future<List<CoachClientModel>> getClients() => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>('/coach/clients');
    return [
      for (final json in response.data!)
        CoachClientModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-05 — `GET /coach/clients/{clientId}/goals`.
  Future<List<GoalModel>> getClientGoals(String clientId) =>
      _getGoals('/coach/clients/$clientId/goals');

  /// HU-05 — `POST /coach/clients/{clientId}/goals` (201).
  Future<GoalModel> setClientGoal(
    String clientId, {
    required int calories,
    required int proteinG,
    required int fatG,
    required DateTime effectiveFrom,
  }) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coach/clients/$clientId/goals',
      data: {
        'calories': calories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'effective_from': _formatDate(effectiveFrom),
      },
    );
    return GoalModel.fromJson(response.data!);
  });

  Future<List<GoalModel>> _getGoals(String path) => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>(path);
    return [
      for (final json in response.data!)
        GoalModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// `YYYY-MM-DD`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
