import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/progress/data/datasources/progress_remote_data_source.dart';
import 'package:macrofit_app/features/progress/data/repositories/progress_repository_impl.dart';

import '../../../helpers/fakes.dart';

/// Respuesta `200` del contrato de `GET /users/me/progress` (HU-22-API, README de la
/// feature): dos pesos, un día con meta y otro todavía sin meta, y una semana.
final _progressJson = {
  'from': '2026-10-30',
  'to': '2026-11-05',
  'weights': [
    {'weight_kg': 73.1, 'recorded_at': '2026-10-30T15:00:00Z'},
    {'weight_kg': 72.4, 'recorded_at': '2026-11-04T15:00:00Z'},
  ],
  'days': [
    {
      'date': '2026-10-30',
      'goal': {
        'source': 'system',
        'calories_kcal': 2000,
        'protein_g': 150,
        'fat_g': 60,
      },
      'consumed': {'calories_kcal': 1900, 'protein_g': 140.5, 'fat_g': 55},
      'goal_met': true,
    },
    {
      'date': '2026-10-31',
      'goal': null,
      'consumed': {'calories_kcal': 0, 'protein_g': 0, 'fat_g': 0},
      'goal_met': false,
    },
  ],
  'compliance': [
    {
      'week_start': '2026-10-30',
      'week_end': '2026-11-05',
      'completed_sessions': 2,
      'planned_sessions': 4,
    },
  ],
};

void main() {
  late FakeHttpAdapter adapter;
  late ProgressRepositoryImpl repository;

  void respond(Object body, int status) {
    adapter = FakeHttpAdapter((_) => jsonResponse(body, status));
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));
  }

  test('pide el periodo y convierte pesos, días y cumplimiento', () async {
    respond(_progressJson, 200);

    final report = await repository.getProgress(
      from: '2026-10-30',
      to: '2026-11-05',
    );

    final request = adapter.requests.single;
    expect(request.path, '/users/me/progress');
    expect(request.queryParameters, {'from': '2026-10-30', 'to': '2026-11-05'});
    expect(report.weights.map((w) => w.weightKg), [73.1, 72.4]);
    expect(report.weights.first.recordedAt, DateTime.utc(2026, 10, 30, 15));
    expect(report.days.first.goal?.caloriesKcal, 2000);
    expect(report.days.first.consumed.proteinG, 140.5);
    expect(report.days.first.goalMet, isTrue);
    expect(report.days.last.goal, isNull);
    expect(report.compliance.single.completedSessions, 2);
    expect(report.compliance.single.plannedSessions, 4);
    expect(report.hasWeightTrend, isTrue);
    expect(report.hasMeals, isTrue);
    expect(report.hasCompliance, isTrue);
  });

  test('un periodo sin datos llega con listas vacías y sin gráficas', () async {
    respond({
      'from': '2026-10-30',
      'to': '2026-11-05',
      'weights': <Object>[],
      'days': <Object>[],
      'compliance': <Object>[],
    }, 200);

    final report = await repository.getProgress(
      from: '2026-10-30',
      to: '2026-11-05',
    );

    expect(report.hasWeightTrend, isFalse);
    expect(report.hasMeals, isFalse);
    expect(report.hasCompliance, isFalse);
  });

  test('un error de la API llega como ApiException con su código', () async {
    adapter = FakeHttpAdapter(
      (_) => errorResponse(ApiErrorCode.validation, 400),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    expect(
      () => repository.getProgress(from: '2026-11-05', to: '2026-10-30'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.validation,
        ),
      ),
    );
  });
}
