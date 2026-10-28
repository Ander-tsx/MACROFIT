import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/clients/data/datasources/clients_remote_data_source.dart';
import 'package:macrofit_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;

  ClientsRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ClientsRepositoryImpl(ClientsRemoteDataSource(dio));
  }

  test('lista los clientes con su meta vigente y su último registro', () async {
    final repository = build(
      (_) => jsonResponse([
        {
          'id': testClient.id,
          'name': 'Ana',
          'email': 'ana@macrofit.test',
          'goal': {
            'calories': 2200,
            'protein_g': 160,
            'fat_g': 70,
            'source': 'coach',
          },
          'last_meal_at': '2026-10-17T01:30:00Z',
        },
      ], 200),
    );

    final clients = await repository.getClients();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/coach/clients');
    final client = clients.single;
    expect(client.id, testClient.id);
    expect(client.name, 'Ana');
    expect(client.email, 'ana@macrofit.test');
    expect(
      client.goal,
      const ClientGoalSummary(
        calories: 2200,
        proteinG: 160,
        fatG: 70,
        source: GoalSource.coach,
      ),
    );
    expect(client.lastMealAt, DateTime.utc(2026, 10, 17, 1, 30));
  });

  test(
    'un cliente sin metas ni registros llega con goal y last_meal_at nulos',
    () async {
      final repository = build(
        (_) => jsonResponse([
          {
            'id': testClientWithoutData.id,
            'name': 'José Pérez',
            'email': 'jose@macrofit.test',
            'goal': null,
            'last_meal_at': null,
          },
        ], 200),
      );

      final client = (await repository.getClients()).single;

      expect(client.goal, isNull);
      expect(client.lastMealAt, isNull);
    },
  );

  test(
    'una meta calculada conserva su origen y redondea los valores',
    () async {
      final repository = build(
        (_) => jsonResponse([
          {
            'id': 'abc',
            'name': 'Beto',
            'email': 'beto@macrofit.test',
            'goal': {
              'calories': 1987.6,
              'protein_g': 144.2,
              'fat_g': 55.5,
              'source': 'system',
            },
            'last_meal_at': null,
          },
        ], 200),
      );

      final goal = (await repository.getClients()).single.goal!;

      expect(goal.source, GoalSource.system);
      expect(goal.calories, 1988);
      expect(goal.proteinG, 144);
      expect(goal.fatG, 56);
    },
  );

  test('una cuenta que no es coach recibe FORBIDDEN_ROLE', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.forbiddenRole, 403),
    );

    await expectLater(
      repository.getClients(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.forbiddenRole,
        ),
      ),
    );
  });
}
