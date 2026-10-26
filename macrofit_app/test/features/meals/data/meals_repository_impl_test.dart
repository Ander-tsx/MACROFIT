import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/data/datasources/meals_remote_data_source.dart';
import 'package:macrofit_app/features/meals/data/models/meal_estimate_model.dart';
import 'package:macrofit_app/features/meals/data/repositories/meals_repository_impl.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_estimate.dart';

import '../../../helpers/fakes.dart';

/// Respuesta `200` del contrato de `POST /meals/estimate` (backend/README.md).
final _estimateJson = {
  'photo_id': testUploadedPhoto.id,
  'foods': [
    {
      'name': 'Arroz blanco cocido',
      'grams': 150.0,
      'calories_kcal': 195.0,
      'protein_g': 4.0,
      'fat_g': 0.4,
    },
    {
      'name': 'Pechuga de pollo a la plancha',
      'grams': null,
      'calories_kcal': 218,
      'protein_g': 38.2,
      'fat_g': 4.5,
    },
  ],
  'totals': {'calories_kcal': 413.0, 'protein_g': 42.2, 'fat_g': 4.9},
};

void main() {
  late FakeHttpAdapter adapter;

  MealsRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return MealsRepositoryImpl(MealsRemoteDataSource(dio));
  }

  group('estimación (POST /meals/estimate)', () {
    test(
      'manda el photo_id y convierte alimentos y totales a la entidad',
      () async {
        final repository = build((_) => jsonResponse(_estimateJson, 200));

        final estimate = await repository.estimate(testUploadedPhoto.id);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/meals/estimate');
        expect(request.data, {'photo_id': testUploadedPhoto.id});
        expect(estimate.photoId, testUploadedPhoto.id);
        expect(estimate.foods, testEstimate.foods);
        expect(estimate.totals, testEstimate.totals);
      },
    );

    test('grams nulo llega como porción desconocida', () async {
      final repository = build((_) => jsonResponse(_estimateJson, 200));

      final estimate = await repository.estimate(testUploadedPhoto.id);

      expect(estimate.foods.first.grams, 150);
      expect(estimate.foods.last.grams, isNull);
    });

    for (final (code, status) in [
      (ApiErrorCode.foodNotRecognized, 422),
      (ApiErrorCode.foodProviderError, 502),
      (ApiErrorCode.foodProviderTimeout, 504),
      (ApiErrorCode.photoNotFound, 404),
    ]) {
      test('$status se traduce a ApiException $code', () async {
        final repository = build((_) => errorResponse(code, status));

        await expectLater(
          repository.estimate(testUploadedPhoto.id),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    test('sin conexión lanza NETWORK_ERROR', () async {
      final repository = build(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'sin red',
        ),
      );

      await expectLater(
        repository.estimate(testUploadedPhoto.id),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'red', isTrue)),
      );
    });
  });

  group('registro (POST /meals)', () {
    Map<String, Object?> mealJson({Object? photoId, Object? estimated}) => {
      'id': '6ad0a1b2c3d4e5f6a7b8c9d0',
      'photo_id': photoId,
      'eaten_at': '2026-10-17T01:30:00Z',
      'date': '2026-10-16',
      'calories_kcal': 380.0,
      'protein_g': 40,
      'fat_g': 6.5,
      'estimated': estimated,
    };

    test(
      'con estimación manda photo_id, los finales planos y estimated',
      () async {
        final repository = build(
          (_) => jsonResponse(
            mealJson(
              photoId: testUploadedPhoto.id,
              estimated: {
                'calories_kcal': 413,
                'protein_g': 42.2,
                'fat_g': 4.9,
              },
            ),
            201,
          ),
        );

        final meal = await repository.createMeal(
          NewMeal(
            photoId: testUploadedPhoto.id,
            values: const NutritionValues(
              caloriesKcal: 380,
              proteinG: 40,
              fatG: 6.5,
            ),
            estimated: testEstimate.totals,
          ),
        );

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/meals');
        expect(request.data, {
          'photo_id': testUploadedPhoto.id,
          'calories_kcal': 380.0,
          'protein_g': 40.0,
          'fat_g': 6.5,
          'estimated': {
            'calories_kcal': 413.0,
            'protein_g': 42.2,
            'fat_g': 4.9,
          },
        });
        expect(meal.id, '6ad0a1b2c3d4e5f6a7b8c9d0');
        expect(meal.photoId, testUploadedPhoto.id);
        expect(meal.eatenAt, DateTime.utc(2026, 10, 17, 1, 30));
        expect(meal.date, DateTime(2026, 10, 16));
        expect(
          meal.values,
          const NutritionValues(caloriesKcal: 380, proteinG: 40, fatG: 6.5),
        );
        expect(meal.estimated, testEstimate.totals);
      },
    );

    test(
      'una captura manual sin foto no manda photo_id ni estimated',
      () async {
        final repository = build((_) => jsonResponse(mealJson(), 201));

        final meal = await repository.createMeal(
          const NewMeal(
            values: NutritionValues(caloriesKcal: 380, proteinG: 40, fatG: 6.5),
          ),
        );

        expect(adapter.requests.single.data, {
          'calories_kcal': 380.0,
          'protein_g': 40.0,
          'fat_g': 6.5,
        });
        expect(meal.photoId, isNull);
        expect(meal.estimated, isNull);
      },
    );

    test('400 VALIDATION_ERROR trae los campos de estimated', () async {
      final repository = build(
        (_) => jsonResponse({
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Datos inválidos',
            'fields': {'estimated.fat_g': 'No puede ser negativo'},
          },
        }, 400),
      );

      await expectLater(
        repository.createMeal(
          NewMeal(photoId: 'x', values: testEstimate.totals),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.validation)
              .having((e) => e.fields, 'fields', {
                'estimated.fat_g': 'No puede ser negativo',
              }),
        ),
      );
    });
  });

  test('el modelo lee y escribe los nombres de la API', () {
    final model = MealEstimateModel.fromJson(_estimateJson);

    expect(jsonDecode(jsonEncode(model.toJson())), _estimateJson);
    expect(
      model.toEntity().totals,
      const NutritionValues(caloriesKcal: 413, proteinG: 42.2, fatG: 4.9),
    );
  });
}
