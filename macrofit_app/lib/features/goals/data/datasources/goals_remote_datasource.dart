import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/exceptions/goals_exceptions.dart';
import '../models/goal_model.dart';

abstract class GoalsRemoteDataSource {
  Future<GoalModel> getCurrentGoal();
  Future<List<GoalModel>> getGoalsHistory();
}

class GoalsRemoteDataSourceImpl implements GoalsRemoteDataSource {
  final http.Client client;
  final String baseUrl; 
  final Future<String?> Function() tokenProvider;

  GoalsRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
    required this.tokenProvider,
  });

  @override
  Future<GoalModel> getCurrentGoal() async {
    final response = await _get('/api/v1/users/me/goals/current');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GoalModel.fromJson(body);
  }

  @override
  Future<List<GoalModel>> getGoalsHistory() async {
    final response = await _get('/api/v1/users/me/goals');
    final decoded = jsonDecode(response.body);
    final list = decoded is List ? decoded : decoded['goals'] as List;
    return list
        .map((e) => GoalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<http.Response> _get(String path) async {
    final token = await tokenProvider();
    final response = await client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    switch (response.statusCode) {
      case 200:
        return response;
      case 404:
        final body = _tryDecode(response.body);
        if (body?['code'] == 'PROFILE_NOT_FOUND') {
          throw ProfileNotFoundException(
              body?['message']?.toString() ?? 'Perfil no encontrado');
        }
        throw GoalsServerException('No encontrado', 404);
      case 403:
        throw const GoalsForbiddenException();
      default:
        throw GoalsServerException(
            'Error inesperado del servidor', response.statusCode);
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
