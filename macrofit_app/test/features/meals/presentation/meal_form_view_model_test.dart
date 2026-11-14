import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_estimate.dart';
import 'package:macrofit_app/features/meals/presentation/meal_form/meal_form_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeMealsRepository repository;

  MealFormViewModel build(MealDraft draft) =>
      MealFormViewModel(repository: repository, draft: draft);

  final fromEstimate = MealDraft(
    photo: testPhotoUpload,
    estimated: testEstimate.totals,
  );

  setUp(() => repository = FakeMealsRepository());

  group('con estimación', () {
    test('se precarga con las calorías, proteína y grasa estimadas', () {
      final viewModel = build(fromEstimate);

      expect(viewModel.isManual, isFalse);
      expect(viewModel.calories, '413');
      expect(viewModel.protein, '42.2');
      expect(viewModel.fat, '4.9');
    });

    test(
      'sin corrección manda los mismos valores como finales y en estimated',
      () async {
        final viewModel = build(fromEstimate);

        final saved = await viewModel.submit();

        expect(saved, isTrue);
        expect(
          repository.created.single,
          NewMeal(
            photoId: testUploadedPhoto.id,
            values: testEstimate.totals,
            estimated: testEstimate.totals,
          ),
        );
        expect(viewModel.saved, isNotNull);
      },
    );

    test(
      'sin corrección conserva el estimado exacto aunque se muestre redondeado',
      () async {
        const estimated = NutritionValues(
          caloriesKcal: 412.96,
          proteinG: 42.25,
          fatG: 4.94,
        );
        final viewModel = build(
          MealDraft(photo: testPhotoUpload, estimated: estimated),
        );
        expect(viewModel.calories, '413');

        await viewModel.submit();

        expect(repository.created.single.values, estimated);
      },
    );

    test('con corrección, estimated conserva lo estimado y los finales lo corregido', () async {
      final viewModel = build(fromEstimate)
        ..setCalories('380')
        ..setFat('6,5');

      await viewModel.submit();

      final meal = repository.created.single;
      expect(
        meal.values,
        const NutritionValues(caloriesKcal: 380, proteinG: 42.2, fatG: 6.5),
      );
      expect(meal.estimated, testEstimate.totals);
      expect(meal.photoId, testUploadedPhoto.id);
    });
  });

  group('captura manual', () {
    test('tras un fallo de la estimación empieza vacía y se manda con la foto y sin estimated', () async {
      final viewModel = build(MealDraft(photo: testPhotoUpload));
      expect(viewModel.isManual, isTrue);
      expect(
        [viewModel.calories, viewModel.protein, viewModel.fat],
        ['', '', ''],
      );

      viewModel
        ..setCalories('520')
        ..setProtein('30')
        ..setFat('18');
      await viewModel.submit();

      expect(
        repository.created.single,
        NewMeal(
          photoId: testUploadedPhoto.id,
          values: const NutritionValues(
            caloriesKcal: 520,
            proteinG: 30,
            fatG: 18,
          ),
        ),
      );
    });

    test('sin foto se manda sin photo_id ni estimated', () async {
      final viewModel = build(const MealDraft())
        ..setCalories('0')
        ..setProtein('0')
        ..setFat('0');

      await viewModel.submit();

      final meal = repository.created.single;
      expect(meal.photoId, isNull);
      expect(meal.estimated, isNull);
      expect(
        meal.values,
        const NutritionValues(caloriesKcal: 0, proteinG: 0, fatG: 0),
      );
    });
  });

  group('errores', () {
    test('la validación local marca cada campo y no llama a la API', () async {
      final viewModel = build(const MealDraft())
        ..setCalories('-5')
        ..setProtein('abc');

      final saved = await viewModel.submit();

      expect(saved, isFalse);
      expect(repository.created, isEmpty);
      expect(
        viewModel.errorFor(MealFormViewModel.caloriesField),
        'No puede ser negativo',
      );
      expect(
        viewModel.errorFor(MealFormViewModel.proteinField),
        'Debe ser un número',
      );
      expect(
        viewModel.errorFor(MealFormViewModel.fatField),
        'La grasa es obligatoria',
      );
    });

    test('editar un campo limpia su error', () async {
      final viewModel = build(const MealDraft());
      await viewModel.submit();
      expect(viewModel.errorFor(MealFormViewModel.caloriesField), isNotNull);

      viewModel.setCalories('300');

      expect(viewModel.errorFor(MealFormViewModel.caloriesField), isNull);
      expect(viewModel.errorFor(MealFormViewModel.fatField), isNotNull);
    });

    test(
      '400 VALIDATION_ERROR marca cada campo, incluidos los de estimated',
      () async {
        final viewModel = build(fromEstimate);
        repository.createError = apiError(
          ApiErrorCode.validation,
          fields: {
            'calories_kcal': 'No puede ser mayor a 10000',
            'estimated.fat_g': 'No puede ser negativo',
          },
        );

        final saved = await viewModel.submit();

        expect(saved, isFalse);
        expect(
          viewModel.errorFor(MealFormViewModel.caloriesField),
          'No puede ser mayor a 10000',
        );
        expect(
          viewModel.errorFor(MealFormViewModel.fatField),
          'Valor estimado: No puede ser negativo',
        );
        expect(viewModel.errorFor(MealFormViewModel.proteinField), isNull);
        expect(viewModel.generalError, isNull);
      },
    );

    for (final (code, status) in [
      ('PHOTO_ALREADY_USED', 409),
      (ApiErrorCode.photoNotFound, 404),
    ]) {
      test('$status $code muestra el mensaje sin perder los valores', () async {
        final viewModel = build(fromEstimate)..setCalories('380');
        repository.createError = apiError(
          code,
          status: status,
          fields: {'photo_id': 'mensaje del campo'},
          message: 'Mensaje en español',
        );

        await viewModel.submit();

        expect(viewModel.generalError, 'Mensaje en español');
        expect(viewModel.calories, '380');
        expect(viewModel.saved, isNull);
      });
    }

    test('sin conexión muestra el error y permite reintentar', () async {
      final viewModel = build(fromEstimate);
      repository.createError = networkError;

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.generalError, networkError.message);

      repository.createError = null;
      expect(await viewModel.submit(), isTrue);
      expect(repository.created, hasLength(2));
    });

    test('un registro guardado no se vuelve a enviar', () async {
      final viewModel = build(fromEstimate);

      await viewModel.submit();
      expect(await viewModel.submit(), isFalse);

      expect(repository.created, hasLength(1));
    });
  });
}
