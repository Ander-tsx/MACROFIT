import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/clients/presentation/client_meals/client_meals_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 16, 21, 15);
  final today = DateTime(2026, 10, 16);
  final yesterday = DateTime(2026, 10, 15);

  ClientMealsViewModel build(FakeClientsRepository repository) =>
      ClientMealsViewModel(
        repository: repository,
        client: testClientSummary,
        clock: () => now,
      );

  test('empieza en el día de hoy y trae sus registros', () async {
    final repository = FakeClientsRepository(
      meals: {
        today: [testMealWithPhoto(), testManualMeal()],
      },
    );
    final viewModel = build(repository);
    expect(viewModel.date, today);

    await viewModel.load();

    expect(repository.mealRequests.single.clientId, testClientSummary.id);
    expect(repository.mealRequests.single.date, today);
    expect(viewModel.meals, hasLength(2));
    expect(viewModel.isEmptyDay, isFalse);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.error, isNull);
  });

  test('suma los valores del día', () async {
    final viewModel = build(
      FakeClientsRepository(
        meals: {
          today: [testMealWithPhoto(), testManualMeal()],
        },
      ),
    );

    await viewModel.load();

    expect(viewModel.totals.calories, 793);
    expect(viewModel.totals.proteinG, closeTo(82.2, 1e-9));
    expect(viewModel.totals.fatG, closeTo(11.4, 1e-9));
  });

  test('un día sin registros lo indica', () async {
    final viewModel = build(FakeClientsRepository());

    await viewModel.load();

    expect(viewModel.meals, isEmpty);
    expect(viewModel.isEmptyDay, isTrue);
    expect(viewModel.totals.calories, 0);
  });

  test('antes de cargar no se considera un día vacío', () {
    expect(build(FakeClientsRepository()).isEmptyDay, isFalse);
  });

  test('cambia al día anterior y vuelve, sin pasar de hoy', () async {
    final repository = FakeClientsRepository(
      meals: {
        yesterday: [testManualMeal()],
      },
    );
    final viewModel = build(repository);
    await viewModel.load();
    expect(viewModel.canGoForward, isFalse);

    await viewModel.previousDay();
    expect(viewModel.date, yesterday);
    expect(repository.mealRequests.last.date, yesterday);
    expect(viewModel.meals, hasLength(1));
    expect(viewModel.canGoForward, isTrue);

    await viewModel.nextDay();
    expect(viewModel.date, today);
    expect(viewModel.isEmptyDay, isTrue);

    await viewModel.nextDay();
    expect(viewModel.date, today);
    expect(repository.mealRequests, hasLength(3));
  });

  test('elegir una fecha carga ese día e ignora la hora y el futuro', () async {
    final repository = FakeClientsRepository();
    final viewModel = build(repository);

    await viewModel.selectDate(DateTime(2026, 10, 1, 13, 45));
    expect(viewModel.date, DateTime(2026, 10, 1));
    expect(repository.mealRequests.last.date, DateTime(2026, 10, 1));

    await viewModel.selectDate(DateTime(2026, 11, 1));
    expect(viewModel.date, today);
  });

  test('un cliente desvinculado se indica y no queda como error', () async {
    final repository = FakeClientsRepository()
      ..mealsError = apiError(ApiErrorCode.clientNotLinked, status: 403);
    final viewModel = build(repository);

    await viewModel.load();

    expect(viewModel.isUnlinked, isTrue);
    expect(viewModel.error, isNull);
    expect(viewModel.meals, isEmpty);
  });

  test('sin conexión muestra el error y permite reintentar', () async {
    final repository = FakeClientsRepository(
      meals: {
        today: [testManualMeal()],
      },
    )..mealsError = networkError;
    final viewModel = build(repository);

    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.isUnlinked, isFalse);
    expect(viewModel.isEmptyDay, isFalse);

    repository.mealsError = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.meals, hasLength(1));
  });

  test('cada foto se descarga una sola vez', () async {
    final repository = FakeClientsRepository();
    final viewModel = build(repository);
    const url = '/api/v1/meals/photos/6acd4140ac968514f27322cd';

    final first = await viewModel.photo(url);
    final second = await viewModel.photo(url);

    expect(first, testPhotoBytes);
    expect(second, testPhotoBytes);
    expect(repository.photoRequests, [url]);
  });
}
