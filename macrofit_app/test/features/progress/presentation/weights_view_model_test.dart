import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/profile/domain/validators/profile_validators.dart';
import 'package:macrofit_app/features/progress/data/datasources/weights_remote_data_source.dart';
import 'package:macrofit_app/features/progress/data/models/weight_model.dart';
import 'package:macrofit_app/features/progress/data/repositories/weights_repository_impl.dart';
import 'package:macrofit_app/features/progress/domain/entities/weight_entry.dart';
import 'package:macrofit_app/features/progress/presentation/weights/weights_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('ProfileValidators weight (HU-21 / TEC-12)', () {
    test('rechaza vacío o no numérico', () {
      expect(ProfileValidators.weight(''), 'El peso es obligatorio');
      expect(ProfileValidators.weight('   '), 'El peso es obligatorio');
      expect(ProfileValidators.weight('abc'), 'Escribe un número válido');
    });

    test('rechaza fuera de rango (35 a 250 kg) y acepta coma decimal', () {
      expect(ProfileValidators.weight('34.9'), isNotNull);
      expect(ProfileValidators.weight('250.1'), isNotNull);
      expect(ProfileValidators.weight('35'), isNull);
      expect(ProfileValidators.weight('250'), isNull);
      expect(ProfileValidators.weight('75,5'), isNull);
      expect(ProfileValidators.parseNumber('75,5'), 75.5);
    });
  });

  group('WeightModel.fromJson', () {
    test('convierte JSON correctamente y parsea recorded_at', () {
      const json = {
        'id': 'w1',
        'user_id': 'u1',
        'weight_kg': 78.5,
        'recorded_at': '2026-10-13T16:05:00Z',
      };
      final model = WeightModel.fromJson(json);
      expect(model.id, 'w1');
      expect(model.weightKg, 78.5);
      expect(model.recordedAt.isUtc, true);
      final entity = model.toEntity();
      expect(entity.weightKg, 78.5);
    });
  });

  group(
    'WeightsRemoteDataSource & WeightsRepositoryImpl con FakeHttpAdapter',
    () {
      test(
        'getWeights y createWeight se comunican correctamente con la API',
        () async {
          final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
          final adapter = FakeHttpAdapter((options) async {
            if (options.method == 'GET' &&
                options.path == '/users/me/weights') {
              return jsonResponse([
                {
                  'id': '1',
                  'user_id': 'u1',
                  'weight_kg': 75.0,
                  'recorded_at': '2026-10-13T16:05:00Z',
                },
              ], 200);
            }
            if (options.method == 'POST' &&
                options.path == '/users/me/weights') {
              return jsonResponse({
                'id': '2',
                'user_id': 'u1',
                'weight_kg': 80.0,
                'recorded_at': '2026-10-13T17:00:00Z',
              }, 201);
            }
            return ResponseBody.fromString('Not Found', 404);
          });
          dio.httpClientAdapter = adapter;

          final dataSource = WeightsRemoteDataSource(dio);
          final repository = WeightsRepositoryImpl(dataSource);

          final weights = await repository.getWeights();
          expect(weights.length, 1);
          expect(weights.first.weightKg, 75.0);

          final created = await repository.createWeight(80.0);
          expect(created.weightKg, 80.0);
        },
      );
    },
  );

  group('WeightsViewModel', () {
    test('carga el historial de peso exitosamente', () async {
      final now = DateTime.now();
      final repo = FakeWeightsRepository(
        weights: [WeightEntry(id: '1', weightKg: 78.5, recordedAt: now)],
      );
      final vm = WeightsViewModel(repository: repo);

      await vm.load();
      expect(vm.weights.length, 1);
      expect(vm.weights.first.weightKg, 78.5);
      expect(vm.loadError, null);
    });

    test('maneja error al cargar el historial y permite reintentar', () async {
      final repo = FakeWeightsRepository()
        ..error = const ApiException(
          code: ApiErrorCode.network,
          message: 'Sin conexión',
        );
      final vm = WeightsViewModel(repository: repo);

      await vm.load();
      expect(vm.loadError, 'Sin conexión');

      repo.error = null;
      repo.weights = [
        WeightEntry(id: '1', weightKg: 75.0, recordedAt: DateTime.now()),
      ];
      await vm.load();
      expect(vm.loadError, null);
      expect(vm.weights.length, 1);
    });

    test(
      'registra un peso válido y lo añade al inicio del historial',
      () async {
        final repo = FakeWeightsRepository();
        final vm = WeightsViewModel(repository: repo);

        vm.setWeightInput('80.0');
        final success = await vm.registerWeight();

        expect(success, true);
        expect(vm.weights.length, 1);
        expect(vm.weights.first.weightKg, 80.0);
        expect(vm.weightInput, '');
        expect(vm.fieldErrors, isEmpty);
      },
    );

    test('maneja error de red (sin conexión) al registrar', () async {
      final repo = FakeWeightsRepository()
        ..createError = const ApiException(
          code: ApiErrorCode.network,
          message: 'Sin red',
        );
      final vm = WeightsViewModel(repository: repo);

      vm.setWeightInput('75.0');
      final success = await vm.registerWeight();

      expect(success, false);
      expect(vm.generalError, 'Sin red');
    });

    test('valida localmente peso inválido antes de llamar a la API', () async {
      final repo = FakeWeightsRepository();
      final vm = WeightsViewModel(repository: repo);

      vm.setWeightInput('20'); // Fuera de rango (< 35)
      final success = await vm.registerWeight();

      expect(success, false);
      expect(vm.fieldErrors.containsKey('weight_kg'), true);
      expect(vm.weights, isEmpty);
    });

    test('maneja error de validación 400 de la API', () async {
      final repo = FakeWeightsRepository()
        ..createError = const ApiException(
          code: ApiErrorCode.validation,
          message: 'Inválido',
          fields: {'weight_kg': 'Peso inválido en servidor'},
        );
      final vm = WeightsViewModel(repository: repo);

      vm.setWeightInput('75.0');
      final success = await vm.registerWeight();

      expect(success, false);
      expect(vm.fieldError('weight_kg'), 'Peso inválido en servidor');
    });
  });
}
