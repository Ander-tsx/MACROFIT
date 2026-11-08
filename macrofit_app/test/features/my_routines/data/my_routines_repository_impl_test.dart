import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/my_routines/data/datasources/my_routines_remote_data_source.dart';
import 'package:macrofit_app/features/my_routines/data/repositories/my_routines_repository_impl.dart';
import 'package:macrofit_app/features/my_routines/domain/entities/user_routine.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;

  MyRoutinesRepositoryImpl build(
    ResponseBody Function(RequestOptions) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return MyRoutinesRepositoryImpl(MyRoutinesRemoteDataSource(dio));
  }

  const exerciseJson = {
    'exercise_id': '6ac6a0000000000000000001',
    'name': 'Sentadilla',
    'muscle_group': 'legs',
    'equipment': 'bodyweight',
    'level': 'beginner',
    'sets': 2,
    'reps': 12,
    'rest_seconds': 60,
  };

  const recommendedJson = {
    'id': '6b2a00000000000000000001',
    'origin': 'system',
    'name': 'Rutina recomendada · Mantener · 2 días',
    'objective': 'maintain',
    'level': 'beginner',
    'training_days': 2,
    'sessions': [
      {
        'number': 1,
        'name': 'Día 1 · Cuerpo completo',
        'focus': 'full_body',
        'exercises': [exerciseJson],
      },
      {
        'number': 2,
        'name': 'Día 2 · Cuerpo completo',
        'focus': 'full_body',
        'exercises': [exerciseJson],
      },
    ],
    'created_at': '2026-11-07T18:00:00Z',
  };

  test(
    'la lista trae ambos orígenes con el coach y el número de sesiones',
    () async {
      final repository = build(
        (_) => jsonResponse([
          {
            'id': 'r1',
            'origin': 'system',
            'name': 'Rutina recomendada · Mantener · 3 días',
            'coach_name': null,
            'session_count': 3,
          },
          {
            'id': 'r2',
            'origin': 'coach',
            'name': 'Torso A',
            'coach_name': 'Carlos',
            'session_count': 1,
          },
        ], 200),
      );

      final routines = await repository.getRoutines();

      expect(adapter.requests.single.path, '/users/me/routines');
      expect(routines, const [
        UserRoutineSummary(
          id: 'r1',
          origin: RoutineOrigin.system,
          name: 'Rutina recomendada · Mantener · 3 días',
          sessionCount: 3,
        ),
        UserRoutineSummary(
          id: 'r2',
          origin: RoutineOrigin.coach,
          name: 'Torso A',
          coachName: 'Carlos',
          sessionCount: 1,
        ),
      ]);
    },
  );

  test(
    'el detalle trae cada sesión con ejercicios, series, reps y descanso',
    () async {
      final repository = build(
        (_) => jsonResponse({
          'id': 'r2',
          'origin': 'coach',
          'name': 'Torso A',
          'coach_name': 'Carlos',
          'sessions': [
            {
              'number': 1,
              'name': 'Torso A',
              'exercises': [exerciseJson],
            },
          ],
        }, 200),
      );

      final routine = await repository.getRoutine('r2');

      expect(adapter.requests.single.path, '/routines/r2');
      expect(routine.origin, RoutineOrigin.coach);
      expect(routine.coachName, 'Carlos');
      final session = routine.sessions.single;
      expect(session.number, 1);
      final exercise = session.exercises.single;
      expect(exercise.name, 'Sentadilla');
      expect(exercise.muscleGroup, 'legs');
      expect((exercise.sets, exercise.reps, exercise.restSeconds), (2, 12, 60));
    },
  );

  test('una rutina no disponible responde ROUTINE_NOT_FOUND', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.routineNotFound, 404),
    );

    await expectLater(
      repository.getRoutine('r9'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.routineNotFound,
        ),
      ),
    );
  });

  test('pedir la recomendada usa la respuesta de HU-15', () async {
    final repository = build((_) => jsonResponse(recommendedJson, 201));

    final routine = await repository.requestRecommendedRoutine();

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/users/me/routines/recommended');
    expect(routine.id, '6b2a00000000000000000001');
    expect(routine.origin, RoutineOrigin.system);
    expect(routine.coachName, isNull);
    expect(routine.sessions.map((s) => s.number), [1, 2]);
    expect(routine.toSummary().sessionCount, 2);
  });

  test('un origen desconocido se trata como recomendada', () {
    expect(RoutineOrigin.fromApi('coach'), RoutineOrigin.coach);
    expect(RoutineOrigin.fromApi('system'), RoutineOrigin.system);
    expect(RoutineOrigin.fromApi('otro'), RoutineOrigin.system);
  });
}
