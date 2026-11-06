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

  group('contrato real (`ProgressResponse` del backend)', () {
    test(
      'HU-22: convierte `daily`, la meta en `totals` y `compliance`',
      () async {
        respond(_backendJson, 200);

        final report = await repository.getProgress(
          from: '2026-10-30',
          to: '2026-11-05',
        );

        // Sin `from`/`to` en la respuesta, el periodo es el pedido.
        expect(report.from, '2026-10-30');
        expect(report.to, '2026-11-05');
        expect(report.weights.map((w) => w.weightKg), [73.1, 72.4]);
        expect(report.days, hasLength(2));
        expect(report.days.first.goal?.caloriesKcal, 2000);
        expect(report.days.first.goal?.proteinG, 150);
        expect(report.days.first.consumed.caloriesKcal, 1900);
        // Sin `goal_met`: 1900 de 2000 kcal está entre el 90 % y el 110 %.
        expect(report.days.first.goalMet, isTrue);
        // Un día sin comidas no cumple aunque tenga meta.
        expect(report.days.last.goalMet, isFalse);
        final week = report.compliance.single;
        expect(week.weekStart, '2026-10-30');
        expect(week.weekEnd, '2026-11-05');
        expect(week.completedSessions, 1);
        expect(week.plannedSessions, 3);
        expect(report.hasMeals, isTrue);
        expect(report.hasCompliance, isTrue);
      },
    );

    test('HU-23: pide el progreso del cliente con el periodo', () async {
      respond(_backendJson, 200);

      final report = await repository.getClientProgress(
        clientId: 'client-1',
        from: '2026-10-30',
        to: '2026-11-05',
      );

      final request = adapter.requests.single;
      expect(request.path, '/coach/clients/client-1/progress');
      expect(request.queryParameters, {
        'from': '2026-10-30',
        'to': '2026-11-05',
      });
      expect(report.days, hasLength(2));
      expect(report.hasWeightTrend, isTrue);
    });

    test('HU-23: `403 CLIENT_NOT_LINKED` llega como ApiException', () async {
      adapter = FakeHttpAdapter(
        (_) => errorResponse(ApiErrorCode.clientNotLinked, 403),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = adapter;
      repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

      expect(
        () => repository.getClientProgress(
          clientId: 'client-1',
          from: '2026-10-30',
          to: '2026-11-05',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            ApiErrorCode.clientNotLinked,
          ),
        ),
      );
    });
  });
}

/// Respuesta `200` tal como la arma `backend/src/services/progress.rs`
/// (`ProgressResponse`): `weights`, `daily` (`DailySummary`) y `compliance`.
final _backendJson = {
  'weights': [
    {
      'id': 'w1',
      'user_id': 'u1',
      'weight_kg': 73.1,
      'recorded_at': '2026-10-30T15:00:00Z',
    },
    {
      'id': 'w2',
      'user_id': 'u1',
      'weight_kg': 72.4,
      'recorded_at': '2026-11-04T15:00:00Z',
    },
  ],
  'daily': [
    {
      'date': '2026-10-30',
      'goal': {
        'source': 'coach',
        'totals': {'calories_kcal': 2000, 'protein_g': 150, 'fat_g': 60},
      },
      'consumed': {'calories_kcal': 1900, 'protein_g': 140, 'fat_g': 55},
      'remaining': {'calories_kcal': 100, 'protein_g': 10, 'fat_g': 5},
    },
    {
      'date': '2026-10-31',
      'goal': {
        'source': 'system',
        'totals': {'calories_kcal': 2000, 'protein_g': 150, 'fat_g': 60},
      },
      'consumed': {'calories_kcal': 0, 'protein_g': 0, 'fat_g': 0},
      'remaining': {'calories_kcal': 2000, 'protein_g': 150, 'fat_g': 60},
    },
  ],
  'compliance': [
    {
      'start': '2026-10-30',
      'end': '2026-11-05',
      'training_days': 3,
      'completed_sessions': 1,
    },
  ],
};
