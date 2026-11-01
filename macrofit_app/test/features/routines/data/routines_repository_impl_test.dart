import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/routines/data/datasources/routines_remote_data_source.dart';
import 'package:macrofit_app/features/routines/data/repositories/routines_repository_impl.dart';
import 'package:macrofit_app/features/routines/domain/entities/exercise.dart';
import 'package:macrofit_app/features/routines/domain/entities/routine.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;

  RoutinesRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return RoutinesRepositoryImpl(RoutinesRemoteDataSource(dio));
  }

  const routineJson = {
    'id': '6b01a0000000000000000001',
    'name': 'Torso A',
    'exercises': [
      {
        'exercise_id': '6ac6a0000000000000000001',
        'name': 'Press de banca con mancuernas',
        'muscle_group': 'chest',
        'sets': 4,
        'reps': 10,
        'rest_seconds': 90,
      },
      {
        'exercise_id': '6ac6a0000000000000000003',
        'name': 'Remo con barra',
        'muscle_group': 'back',
        'sets': 3,
        'reps': 12,
        'rest_seconds': 60,
      },
    ],
    'created_at': '2026-10-26T18:00:00Z',
    'updated_at': '2026-10-26T18:00:00Z',
  };

  const draft = RoutineDraft(
    name: 'Torso A',
    exercises: [
      RoutineExerciseDraft(
        exerciseId: '6ac6a0000000000000000001',
        sets: 4,
        reps: 10,
        restSeconds: 90,
      ),
    ],
  );

  Object? body(RequestOptions options) => options.data is String
      ? jsonDecode(options.data as String)
      : options.data;

  group('catálogo (GET /exercises)', () {
    test(
      'sin filtros no manda parámetros y convierte cada ejercicio',
      () async {
        final repository = build(
          (_) => jsonResponse([
            {
              'id': '6ac6a0000000000000000002',
              'name': 'Flexiones de pecho',
              'muscle_group': 'chest',
              'equipment': 'bodyweight',
              'level': 'beginner',
              'created_at': '2026-10-13T12:00:00Z',
            },
          ], 200),
        );

        final exercises = await repository.getExercises();

        expect(exercises, [testPushUps]);
        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/exercises');
        expect(request.queryParameters, isEmpty);
      },
    );

    test('manda grupo muscular y nivel como parámetros', () async {
      final repository = build((_) => jsonResponse(<Object>[], 200));

      await repository.getExercises(
        muscleGroup: MuscleGroup.chest,
        level: ExerciseLevel.beginner,
      );

      expect(adapter.requests.single.queryParameters, {
        'muscle_group': 'chest',
        'level': 'beginner',
      });
    });
  });

  test('lista las rutinas con GET /coach/routines', () async {
    final repository = build((_) => jsonResponse([routineJson], 200));

    final routines = await repository.getRoutines();

    expect(routines, [testRoutine]);
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/coach/routines');
  });

  test('crea con POST /coach/routines y los nombres de la API', () async {
    final repository = build((_) => jsonResponse(routineJson, 201));

    final routine = await repository.createRoutine(draft);

    expect(routine, testRoutine);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/coach/routines');
    expect(body(request), {
      'name': 'Torso A',
      'exercises': [
        {
          'exercise_id': '6ac6a0000000000000000001',
          'sets': 4,
          'reps': 10,
          'rest_seconds': 90,
        },
      ],
    });
  });

  test('edita con PUT /coach/routines/{id}', () async {
    final repository = build((_) => jsonResponse(routineJson, 200));

    await repository.updateRoutine('6b01a0000000000000000001', draft);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/coach/routines/6b01a0000000000000000001');
    expect(body(request), containsPair('name', 'Torso A'));
  });

  test('elimina con DELETE /coach/routines/{id} (204 sin cuerpo)', () async {
    final repository = build((_) => ResponseBody.fromString('', 204));

    await repository.deleteRoutine('6b01a0000000000000000001');

    expect(adapter.requests.single.method, 'DELETE');
    expect(
      adapter.requests.single.path,
      '/coach/routines/6b01a0000000000000000001',
    );
  });

  test('un 400 conserva los errores por campo de cada ejercicio', () async {
    final repository = build(
      (_) => jsonResponse({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Datos inválidos',
          'fields': {
            'exercises[0].exercise_id': 'El ejercicio no existe en el catálogo',
          },
        },
      }, 400),
    );

    await expectLater(
      repository.createRoutine(draft),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.validation)
            .having((e) => e.fields, 'fields', {
              'exercises[0].exercise_id':
                  'El ejercicio no existe en el catálogo',
            }),
      ),
    );
  });

  test('una rutina ajena o inexistente lanza ROUTINE_NOT_FOUND', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.routineNotFound, 404),
    );

    await expectLater(
      repository.deleteRoutine('otra'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.routineNotFound)
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('sin red lanza NETWORK_ERROR', () async {
    final repository = build(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      ),
    );

    await expectLater(
      repository.getExercises(),
      throwsA(
        isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue),
      ),
    );
  });
}
