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

/// Respuesta `200` del contrato de `GET /users/me/summary/weekly` (backend/README.md):
/// el primer día sin registros y el segundo con la meta del coach cumplida.
Map<String, dynamic> _day(
  String date, {
  required String source,
  required num goal,
  required num consumed,
  required bool met,
}) => {
  'date': date,
  'goal': {
    'source': source,
    'calories_kcal': goal,
    'protein_g': 140,
    'fat_g': 51,
  },
  'consumed': {'calories_kcal': consumed, 'protein_g': 0, 'fat_g': 0},
  'remaining': {
    'calories_kcal': goal - consumed,
    'protein_g': 140,
    'fat_g': 51,
  },
  'goal_met': met,
};

final _weeklyJson = {
  'start': '2026-10-16',
  'end': '2026-10-22',
  'days': [
    _day('2026-10-16', source: 'system', goal: 1843, consumed: 0, met: false),
    _day('2026-10-17', source: 'coach', goal: 2000, consumed: 1900, met: true),
    for (var i = 18; i <= 22; i++)
      _day('2026-10-$i', source: 'coach', goal: 2000, consumed: 0, met: false),
  ],
  'average': {'calories_kcal': 263.3, 'protein_g': 17.2, 'fat_g': 7.9},
  'goal_met_days': 1,
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

  group('resumen semanal (GET /users/me/summary/weekly)', () {
    test(
      'manda start y convierte los 7 días, el promedio y los días cumplidos',
      () async {
        final repository = build((_) => jsonResponse(_weeklyJson, 200));

        final week = await repository.getWeekly('2026-10-16');

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/users/me/summary/weekly');
        expect(request.queryParameters, {'start': '2026-10-16'});
        expect(week.start, '2026-10-16');
        expect(week.end, '2026-10-22');
        expect(week.days, hasLength(7));
        expect(week.days.first.date, '2026-10-16');
        expect(week.days.last.date, '2026-10-22');
        expect(week.average.caloriesKcal, 263.3);
        expect(week.average.proteinG, 17.2);
        expect(week.average.fatG, 7.9);
        expect(week.goalMetDays, 1);
      },
    );

    test('cada día trae su meta, su consumo y si cumplió (goal_met)', () async {
      final repository = build((_) => jsonResponse(_weeklyJson, 200));

      final week = await repository.getWeekly('2026-10-16');

      expect(week.days[0].goalMet, isFalse);
      expect(week.days[0].consumed.caloriesKcal, 0);
      expect(week.days[0].remaining.caloriesKcal, 1843);
      expect(week.days[1].goalMet, isTrue);
      expect(week.days[1].goal.caloriesKcal, 2000);
      expect(week.days[1].goalSource, GoalSource.coach);
    });

    test(
      '404 PROFILE_NOT_FOUND llega como ApiException con su código',
      () async {
        final repository = build(
          (_) => errorResponse(ApiErrorCode.profileNotFound, 404),
        );

        await expectLater(
          repository.getWeekly('2026-10-16'),
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

    test(
      'un día del resumen diario no trae goal_met y queda en false',
      () async {
        final repository = build((_) => jsonResponse(_dailyJson, 200));

        final summary = await repository.getDaily('2026-10-16');

        expect(summary.goalMet, isFalse);
      },
    );
  });
}
