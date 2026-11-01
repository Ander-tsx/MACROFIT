import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/summary/data/datasources/summary_remote_data_source.dart';
import 'package:macrofit_app/features/summary/data/repositories/summary_repository_impl.dart';

import '../../../helpers/fakes.dart';

/// Respuesta `200` del contrato de `GET /users/me/summary/daily` (backend/README.md).
final _dailyJson = {
  'date': '2026-10-16',
  'goal': {
    'source': 'system',
    'calories_kcal': 2200,
    'protein_g': 160,
    'fat_g': 70,
  },
  'consumed': {'calories_kcal': 1050.5, 'protein_g': 70, 'fat_g': 35.5},
  'remaining': {'calories_kcal': 1149.5, 'protein_g': 90, 'fat_g': 34.5},
};

void main() {
  late FakeHttpAdapter adapter;

  SummaryRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return SummaryRepositoryImpl(SummaryRemoteDataSource(dio));
  }

  group('resumen diario (GET /users/me/summary/daily)', () {
    test('manda la fecha y convierte meta, consumo y restante', () async {
      final repository = build((_) => jsonResponse(_dailyJson, 200));

      final summary = await repository.getDaily('2026-10-16');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/me/summary/daily');
      expect(request.queryParameters, {'date': '2026-10-16'});
      expect(summary.date, '2026-10-16');
      expect(summary.goalSource, GoalSource.system);
      expect(summary.goal.caloriesKcal, 2200);
      expect(summary.goal.proteinG, 160);
      expect(summary.goal.fatG, 70);
      expect(summary.consumed.caloriesKcal, 1050.5);
      expect(summary.remaining.fatG, 34.5);
    });

    test('lee el origen coach y el restante negativo del exceso', () async {
      final repository = build(
        (_) => jsonResponse({
          ..._dailyJson,
          'goal': {
            'source': 'coach',
            'calories_kcal': 2000,
            'protein_g': 150,
            'fat_g': 60,
          },
          'consumed': {'calories_kcal': 2150, 'protein_g': 100, 'fat_g': 60},
          'remaining': {'calories_kcal': -150, 'protein_g': 50, 'fat_g': 0},
        }, 200),
      );

      final summary = await repository.getDaily('2026-10-16');

      expect(summary.goalSource, GoalSource.coach);
      expect(summary.remaining.caloriesKcal, -150);
    });

    test('un día sin registros llega con consumo en 0', () async {
      final repository = build(
        (_) => jsonResponse({
          ..._dailyJson,
          'consumed': {'calories_kcal': 0, 'protein_g': 0, 'fat_g': 0},
          'remaining': {'calories_kcal': 2200, 'protein_g': 160, 'fat_g': 70},
        }, 200),
      );

      final summary = await repository.getDaily('2026-10-16');

      expect(summary.consumed.caloriesKcal, 0);
      expect(summary.remaining.caloriesKcal, 2200);
    });

    test(
      '404 PROFILE_NOT_FOUND llega como ApiException con su código',
      () async {
        final repository = build(
          (_) => errorResponse(ApiErrorCode.profileNotFound, 404),
        );

        await expectLater(
          repository.getDaily('2026-10-16'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.profileNotFound,
            ),
          ),
        );
      },
    );
  });
}
