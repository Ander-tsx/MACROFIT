import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/clients/data/datasources/clients_remote_data_source.dart';
import 'package:macrofit_app/features/clients/data/repositories/clients_repository_impl.dart';

import '../../../helpers/fakes.dart';

const _mealWithPhoto = {
  'id': '6ad0a1b2c3d4e5f6a7b8c9d0',
  'photo_id': '6acd4140ac968514f27322cd',
  'photo_url': '/api/v1/meals/photos/6acd4140ac968514f27322cd',
  'eaten_at': '2026-10-17T01:30:00Z',
  'date': '2026-10-16',
  'calories_kcal': 413.0,
  'protein_g': 42.2,
  'fat_g': 4.9,
};

void main() {
  late FakeHttpAdapter adapter;

  ClientsRepositoryImpl build(
    ResponseBody Function(RequestOptions) handler, {
    Map<String, Object?> headers = const {},
  }) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(
      BaseOptions(baseUrl: 'http://api.test/api/v1', headers: headers),
    )..httpClientAdapter = adapter;
    return ClientsRepositoryImpl(ClientsRemoteDataSource(dio));
  }

  test(
    'pide las comidas del cliente para el día en formato AAAA-MM-DD',
    () async {
      final repository = build((_) => jsonResponse([_mealWithPhoto], 200));

      final meals = await repository.getClientMeals(
        'abc',
        DateTime(2026, 3, 5, 18, 40),
      );

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/coach/clients/abc/meals');
      expect(request.queryParameters, {'date': '2026-03-05'});
      final meal = meals.single;
      expect(meal.id, '6ad0a1b2c3d4e5f6a7b8c9d0');
      expect(meal.photoUrl, '/api/v1/meals/photos/6acd4140ac968514f27322cd');
      expect(meal.eatenAt, DateTime.utc(2026, 10, 17, 1, 30));
      expect(meal.caloriesKcal, 413);
      expect(meal.proteinG, 42.2);
      expect(meal.fatG, 4.9);
    },
  );

  test('una captura manual llega sin foto', () async {
    final repository = build(
      (_) => jsonResponse([
        {
          ..._mealWithPhoto,
          'photo_id': null,
          'photo_url': null,
          'calories_kcal': 380,
          'protein_g': 40,
          'fat_g': 6.5,
        },
      ], 200),
    );

    final meal = (await repository.getClientMeals(
      'abc',
      DateTime(2026),
    )).single;

    expect(meal.photoUrl, isNull);
    expect(meal.caloriesKcal, 380);
  });

  test('un día sin registros devuelve una lista vacía', () async {
    final repository = build((_) => jsonResponse(<Object>[], 200));

    expect(await repository.getClientMeals('abc', DateTime(2026)), isEmpty);
  });

  test('un cliente desvinculado responde CLIENT_NOT_LINKED', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.clientNotLinked, 403),
    );

    await expectLater(
      repository.getClientMeals('abc', DateTime(2026)),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', ApiErrorCode.clientNotLinked)
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
  });

  test(
    'descarga la foto de photo_url con el cliente HTTP con sesión',
    () async {
      final repository = build(
        (_) => ResponseBody.fromBytes(testPhotoBytes, 200),
        headers: {'Authorization': 'Bearer token-del-coach'},
      );

      final bytes = await repository.getMealPhoto(
        '/api/v1/meals/photos/6acd4140ac968514f27322cd',
      );

      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'http://api.test/api/v1/meals/photos/6acd4140ac968514f27322cd',
      );
      expect(request.headers['Authorization'], 'Bearer token-del-coach');
      expect(bytes, testPhotoBytes);
    },
  );

  test('una foto que no se puede descargar lanza ApiException', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.photoNotFound, 404),
    );

    await expectLater(
      repository.getMealPhoto('/api/v1/meals/photos/x'),
      throwsA(isA<ApiException>()),
    );
  });
}
