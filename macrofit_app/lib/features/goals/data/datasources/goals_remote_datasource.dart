import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/exceptions/goals_exceptions.dart';
import '../models/goal_model.dart';

abstract class GoalsRemoteDataSource {
  Future<GoalModel> getCurrentGoal();
  Future<List<GoalModel>> getGoalsHistory();
}

class GoalsRemoteDataSourceImpl implements GoalsRemoteDataSource {
  static const String defaultBaseUrl = 'http://localhost:3000/api/v1';

  final http.Client client;
  final String baseUrl;
  final Future<String?> Function() tokenProvider;

  GoalsRemoteDataSourceImpl({
    required this.client,
    required this.tokenProvider,
    this.baseUrl = defaultBaseUrl,
  });

  @override
  Future<GoalModel> getCurrentGoal() async {
    final response = await _get('/users/me/goals/current');
    return GoalModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<List<GoalModel>> getGoalsHistory() async {
    final response = await _get('/users/me/goals');
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

    if (response.statusCode == 200) return response;

    final body = _tryDecode(response.body);
    final code = _extractCode(body);
    final message = _extractMessage(body);

    switch (response.statusCode) {
      case 404:
        if (code == 'PROFILE_NOT_FOUND') {
          throw ProfileNotFoundException(message ?? 'Perfil no encontrado');
        }
        throw GoalsServerException(message ?? 'No encontrado', 404);
      case 403:
      // El backend responde FORBIDDEN cuando el rol es coach
        throw GoalsForbiddenException(message ?? 'Acceso denegado');
      default:
        throw GoalsServerException(
            message ?? 'Error inesperado del servidor', response.statusCode);
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  // Acepta {"code": ...} o {"error": {"code": ...}}
  String? _extractCode(Map<String, dynamic>? body) {
    final nested = body?['error'];
    if (nested is Map<String, dynamic>) return nested['code']?.toString();
    return body?['code']?.toString();
  }

  String? _extractMessage(Map<String, dynamic>? body) {
    final nested = body?['error'];
    if (nested is Map<String, dynamic>) return nested['message']?.toString();
    return body?['message']?.toString();
  }
}
