import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/my_routines/domain/entities/user_routine.dart';
import 'package:macrofit_app/features/my_routines/presentation/routines_list/my_routines_list_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('sin rutinas indica la lista vacía', () async {
    final viewModel = MyRoutinesListViewModel(FakeMyRoutinesRepository());

    expect(viewModel.hasNoRoutines, isFalse, reason: 'antes de cargar');
    await viewModel.load();

    expect(viewModel.routines, isEmpty);
    expect(viewModel.hasNoRoutines, isTrue);
    expect(viewModel.error, isNull);
  });

  test(
    'muestra la recomendada y la asignada con su origen y su coach',
    () async {
      final viewModel = MyRoutinesListViewModel(
        FakeMyRoutinesRepository(
          routines: [testRecommendedRoutine(), testAssignedRoutine()],
        ),
      );

      await viewModel.load();

      expect(viewModel.routines.map((r) => (r.origin, r.coachName)), [
        (RoutineOrigin.system, null),
        (RoutineOrigin.coach, 'Carlos'),
      ]);
      expect(viewModel.routines.map((r) => r.sessionCount), [3, 1]);
      expect(viewModel.hasNoRoutines, isFalse);
    },
  );

  test('recargar muestra una rutina recién asignada (RF-23)', () async {
    final repository = FakeMyRoutinesRepository(
      routines: [testRecommendedRoutine()],
    );
    final viewModel = MyRoutinesListViewModel(repository);
    await viewModel.load();
    expect(viewModel.routines, hasLength(1));

    repository.routines = [...repository.routines, testAssignedRoutine()];
    await viewModel.load();

    expect(repository.listCalls, 2, reason: 'cada carga consulta la API');
    expect(viewModel.routines.last.name, 'Torso A');
  });

  test('sin conexión muestra el error y conserva la lista anterior', () async {
    final repository = FakeMyRoutinesRepository(
      routines: [testAssignedRoutine()],
    );
    final viewModel = MyRoutinesListViewModel(repository);
    await viewModel.load();

    repository.listError = networkError;
    await viewModel.load();

    expect(viewModel.error, 'Sin conexión');
    expect(viewModel.routines, hasLength(1));
    expect(viewModel.isLoading, isFalse);
  });

  test('sin conexión y sin datos no se confunde con la lista vacía', () async {
    final viewModel = MyRoutinesListViewModel(
      FakeMyRoutinesRepository()..listError = networkError,
    );

    await viewModel.load();

    expect(viewModel.error, 'Sin conexión');
    expect(viewModel.hasNoRoutines, isFalse);
  });

  test(
    'desde la lista vacía pide la recomendada, recarga y devuelve su id',
    () async {
      final repository = FakeMyRoutinesRepository();
      final viewModel = MyRoutinesListViewModel(repository);
      await viewModel.load();

      final id = await viewModel.requestRecommended();

      expect(id, 'rec1');
      expect(repository.recommendedCalls, 1);
      expect(viewModel.routines.single.origin, RoutineOrigin.system);
      expect(viewModel.isRequesting, isFalse);
    },
  );

  test('pedir la recomendada sin perfil explica que falta el perfil', () async {
    final viewModel = MyRoutinesListViewModel(
      FakeMyRoutinesRepository()
        ..recommendedError = apiError(
          ApiErrorCode.profileNotFound,
          status: 404,
        ),
    );

    final id = await viewModel.requestRecommended();

    expect(id, isNull);
    expect(viewModel.requestError, contains('perfil'));
  });
}
