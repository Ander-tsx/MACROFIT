import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_estimate.dart';
import 'package:macrofit_app/features/meals/presentation/meal_history/meal_history_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeMealsRepository repository;
  final now = DateTime(2026, 10, 16, 20, 15);
  final today = DateTime(2026, 10, 16);

  MealHistoryViewModel build({DateTime? initialDate}) => MealHistoryViewModel(
    repository: repository,
    initialDate: initialDate,
    clock: () => now,
  );

  final breakfast = testMeal(
    id: 'desayuno',
    eatenAt: DateTime(2026, 10, 16, 8, 30),
    values: const NutritionValues(caloriesKcal: 350, proteinG: 20, fatG: 10),
  );
  final lunch = testMeal(
    id: 'comida',
    eatenAt: DateTime(2026, 10, 16, 14, 5),
    withPhoto: false,
    values: const NutritionValues(caloriesKcal: 600.5, proteinG: 40, fatG: 22),
  );

  setUp(() {
    repository = FakeMealsRepository()..days[today] = [breakfast, lunch];
  });

  group('cargar el día', () {
    test(
      'empieza en hoy y muestra los registros en el orden de la API',
      () async {
        final viewModel = build();

        await viewModel.load();

        expect(viewModel.date, today);
        expect(repository.listRequests, [today]);
        expect(viewModel.meals, [breakfast, lunch]);
        expect(viewModel.isEmptyDay, isFalse);
      },
    );

    test('con el día del registro guardado empieza en ese día', () async {
      final viewModel = build(initialDate: DateTime(2026, 10, 15, 23, 59));

      await viewModel.load();

      expect(viewModel.date, DateTime(2026, 10, 15));
      expect(repository.listRequests, [DateTime(2026, 10, 15)]);
    });

    test('el total del día suma los valores finales', () async {
      final viewModel = build();
      await viewModel.load();

      expect(
        viewModel.totals,
        const NutritionValues(caloriesKcal: 950.5, proteinG: 60, fatG: 32),
      );
    });

    test('un día sin registros lo indica', () async {
      final viewModel = build(initialDate: DateTime(2026, 10, 10));

      await viewModel.load();

      expect(viewModel.meals, isEmpty);
      expect(viewModel.isEmptyDay, isTrue);
    });

    test('un error muestra el mensaje y reintentar vuelve a cargar', () async {
      final viewModel = build();
      repository.listError = networkError;

      await viewModel.load();
      expect(viewModel.error, networkError.message);
      expect(viewModel.isEmptyDay, isFalse);

      repository.listError = null;
      await viewModel.load();
      expect(viewModel.error, isNull);
      expect(viewModel.meals, hasLength(2));
    });
  });

  group('cambiar de día', () {
    test('el día anterior carga ese día', () async {
      final viewModel = build();
      await viewModel.load();

      await viewModel.previousDay();

      expect(viewModel.date, DateTime(2026, 10, 15));
      expect(repository.listRequests.last, DateTime(2026, 10, 15));
      expect(viewModel.canGoForward, isTrue);
    });

    test('no avanza más allá de hoy', () async {
      final viewModel = build();
      await viewModel.load();
      expect(viewModel.canGoForward, isFalse);

      await viewModel.nextDay();

      expect(viewModel.date, today);
      expect(repository.listRequests, [today]);
    });

    test(
      'elegir una fecha ignora la hora y una fecha futura se lleva a hoy',
      () async {
        final viewModel = build();

        await viewModel.selectDate(DateTime(2026, 10, 12, 18, 40));
        expect(viewModel.date, DateTime(2026, 10, 12));

        await viewModel.selectDate(DateTime(2026, 12, 1));
        expect(viewModel.date, today);
      },
    );
  });

  group('eliminar', () {
    test('quita el registro de la lista y lo avisa una sola vez', () async {
      final viewModel = build();
      await viewModel.load();

      await viewModel.delete(breakfast);

      expect(repository.deleted, ['desayuno']);
      expect(viewModel.meals, [lunch]);
      expect(viewModel.takeNotice(), MealHistoryViewModel.deletedMessage);
      expect(viewModel.takeNotice(), isNull);
      expect(viewModel.deletingId, isNull);
    });

    test('404 MEAL_NOT_FOUND recarga la lista con un mensaje', () async {
      final viewModel = build();
      await viewModel.load();
      // Otro dispositivo ya lo eliminó.
      repository.days[today]!.remove(breakfast);

      await viewModel.delete(breakfast);

      expect(repository.listRequests, [today, today]);
      expect(viewModel.meals, [lunch]);
      expect(
        viewModel.takeNotice(),
        MealHistoryViewModel.alreadyDeletedMessage,
      );
      expect(viewModel.deleteError, isNull);
    });

    test('sin conexión conserva la lista y muestra el error', () async {
      final viewModel = build();
      await viewModel.load();
      repository.deleteError = networkError;

      await viewModel.delete(breakfast);

      expect(viewModel.meals, [breakfast, lunch]);
      expect(viewModel.deleteError, networkError.message);
      expect(viewModel.takeNotice(), isNull);
    });

    test('otro error de la API también conserva la lista', () async {
      final viewModel = build();
      await viewModel.load();
      repository.deleteError = apiError(
        ApiErrorCode.unauthorized,
        status: 401,
        message: 'Tu sesión expiró',
      );

      await viewModel.delete(lunch);

      expect(viewModel.meals, hasLength(2));
      expect(viewModel.deleteError, 'Tu sesión expiró');
    });
  });

  test('cada foto se descarga una sola vez', () async {
    final viewModel = build();
    await viewModel.load();

    final first = viewModel.photo('foto-desayuno');
    final second = viewModel.photo('foto-desayuno');

    expect(identical(first, second), isTrue);
    expect(await first, testPhotoBytes);
    expect(repository.photoRequests, ['foto-desayuno']);
  });
}
