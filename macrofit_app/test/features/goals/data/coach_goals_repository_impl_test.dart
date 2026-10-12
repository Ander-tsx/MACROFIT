import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/goals/data/datasources/goals_remote_datasource.dart';
import 'package:macrofit_app/features/goals/data/repositories/goals_repository_impl.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';

import '../../../helpers/fakes.dart';

const _goalJson = {
  'id': '6ac6aa707314ad6c7164900e',
  'user_id': '6ac67c737314ad6c7164900e',
  'calories': 2200,
  'protein_g': 160,
  'fat_g': 70,
  'source': 'coach',
  'set_by': '6ac67c717314ad6c7164900c',
  'effective_from': '2026-10-09T00:00:00Z',
  'created_at': '2026-10-09T18:00:00Z',
};

void main() {
  late FakeHttpAdapter adapter;

  CoachGoalsRepositoryImpl build(
    ResponseBody Function(RequestOptions) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return CoachGoalsRepositoryImpl(GoalsRemoteDataSource(dio));
  }

  test('lista los clientes vinculados', () async {
    final repository = build(
      (_) => jsonResponse([
        {'id': testClient.id, 'name': 'Ana', 'email': 'ana@macrofit.test'},
      ], 200),
    );

    final clients = await repository.getClients();

    expect(adapter.requests.single.path, '/coach/clients');
    expect(clients.single.id, testClient.id);
    expect(clients.single.name, 'Ana');
  });

  test('consulta el historial de metas de un cliente', () async {
    final repository = build((_) => jsonResponse([_goalJson], 200));

    final history = await repository.getClientGoals('abc');

    expect(adapter.requests.single.path, '/coach/clients/abc/goals');
    expect(history.single.source, GoalSource.coach);
    expect(history.single.calories, 2200);
    expect(history.single.effectiveFrom.toUtc(), DateTime.utc(2026, 10, 9));
  });

  test('fija una meta enviando la fecha como AAAA-MM-DD', () async {
    final repository = build((_) => jsonResponse(_goalJson, 201));

    final goal = await repository.setClientGoal(
      'abc',
      calories: 2200,
      proteinG: 160,
      fatG: 70,
      effectiveFrom: DateTime(2026, 3, 5),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/coach/clients/abc/goals');
    final data = request.data;
    expect(data is String ? jsonDecode(data) : data, {
      'calories': 2200,
      'protein_g': 160,
      'fat_g': 70,
      'effective_from': '2026-03-05',
    });
    expect(goal.calories, 2200);
  });

  test('un coach no vinculado recibe CLIENT_NOT_LINKED', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.clientNotLinked, 403),
    );

    await expectLater(
      repository.getClientGoals('abc'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.clientNotLinked,
        ),
      ),
    );
  });
}
