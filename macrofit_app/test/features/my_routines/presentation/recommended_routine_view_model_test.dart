import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/my_routines/presentation/recommended/recommended_routine_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeMyRoutinesRepository repository;
  late RecommendedRoutineViewModel viewModel;
  late int confirmCalls;

  Future<bool> Function() answer(bool value) => () async {
    confirmCalls++;
    return value;
  };

  setUp(() {
    repository = FakeMyRoutinesRepository();
    viewModel = RecommendedRoutineViewModel(repository);
    confirmCalls = 0;
  });

  group('al abrir', () {
    test('sin recomendada vigente no hay rutina que reemplazar', () async {
      repository.routines = [testAssignedRoutine()];

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.existing, isNull);
      expect(viewModel.routine, isNull);
      expect(repository.recommendedCalls, 0, reason: 'abrir no genera');
    });

    test('encuentra la recomendada vigente entre las rutinas', () async {
      repository.routines = [testRecommendedRoutine(), testAssignedRoutine()];

      await viewModel.load();

      expect(viewModel.existing?.id, 'rec1');
      expect(viewModel.existing?.sessionCount, 3);
    });

    test('sin conexión muestra el error y permite reintentar', () async {
      repository.listError = apiError(ApiErrorCode.network, status: 0);

      await viewModel.load();

      expect(viewModel.loadError, 'Mensaje del servidor');

      repository.listError = null;
      await viewModel.load();

      expect(viewModel.loadError, isNull);
    });
  });

  group('generar', () {
    test('la primera vez no pide confirmación y muestra la rutina', () async {
      await viewModel.load();

      final result = await viewModel.generate(answer(true));

      expect(result, GenerateRoutineResult.generated);
      expect(confirmCalls, 0);
      expect(viewModel.routine?.id, 'rec1');
      expect(viewModel.routine?.trainingDays, 3);
      expect(viewModel.isGenerating, isFalse);
    });

    test('mientras genera está en carga y no envía dos veces', () async {
      await viewModel.load();
      final gate = Completer<void>();
      repository.recommendedGate = gate;

      final first = viewModel.generate(answer(true));
      expect(viewModel.isGenerating, isTrue);

      final second = await viewModel.generate(answer(true));
      expect(second, GenerateRoutineResult.cancelled);
      expect(repository.recommendedCalls, 1);

      gate.complete();
      expect(await first, GenerateRoutineResult.generated);
      expect(viewModel.isGenerating, isFalse);
    });

    test('un error conserva la pantalla y permite reintentar', () async {
      await viewModel.load();
      repository.recommendedError = apiError(ApiErrorCode.network, status: 0);

      expect(
        await viewModel.generate(answer(true)),
        GenerateRoutineResult.failed,
      );
      expect(viewModel.generateError, 'Mensaje del servidor');
      expect(viewModel.routine, isNull);
      expect(viewModel.needsProfile, isFalse);

      repository.recommendedError = null;
      expect(
        await viewModel.generate(answer(true)),
        GenerateRoutineResult.generated,
      );
      expect(viewModel.generateError, isNull);
    });

    test('sin perfil lo indica con un mensaje propio', () async {
      await viewModel.load();
      repository.recommendedError = apiError(
        ApiErrorCode.profileNotFound,
        status: 404,
      );

      expect(
        await viewModel.generate(answer(true)),
        GenerateRoutineResult.failed,
      );
      expect(viewModel.needsProfile, isTrue);
      expect(
        viewModel.generateError,
        'Completa tu perfil para recibir una rutina recomendada.',
      );
    });

    test('catálogo incompleto muestra el mensaje de la API', () async {
      await viewModel.load();
      repository.recommendedError = apiError(
        ApiErrorCode.exerciseCatalogIncomplete,
        status: 503,
        message: 'Faltan ejercicios en el catálogo',
      );

      expect(
        await viewModel.generate(answer(true)),
        GenerateRoutineResult.failed,
      );
      expect(viewModel.generateError, 'Faltan ejercicios en el catálogo');
      expect(viewModel.needsProfile, isFalse);
    });
  });

  group('generar de nuevo', () {
    test('con una vigente pide confirmación; cancelar no genera', () async {
      repository.routines = [testRecommendedRoutine()];
      await viewModel.load();

      final result = await viewModel.generate(answer(false));

      expect(result, GenerateRoutineResult.cancelled);
      expect(confirmCalls, 1);
      expect(repository.recommendedCalls, 0);
      expect(viewModel.existing?.id, 'rec1');
    });

    test('al confirmar muestra la nueva', () async {
      repository.routines = [testRecommendedRoutine(id: 'vieja')];
      await viewModel.load();

      final result = await viewModel.generate(answer(true));

      expect(result, GenerateRoutineResult.generated);
      expect(confirmCalls, 1);
      expect(viewModel.routine?.id, 'rec1');
    });

    test('la rutina recién generada también pide confirmación', () async {
      await viewModel.load();
      await viewModel.generate(answer(true));

      await viewModel.generate(answer(true));

      expect(confirmCalls, 1);
      expect(viewModel.routine?.id, 'rec2');
    });

    test('si falla conserva la rutina que se estaba viendo', () async {
      await viewModel.load();
      await viewModel.generate(answer(true));
      repository.recommendedError = apiError(ApiErrorCode.network, status: 0);

      await viewModel.generate(answer(true));

      expect(viewModel.routine?.id, 'rec1');
      expect(viewModel.generateError, 'Mensaje del servidor');
    });
  });
}
