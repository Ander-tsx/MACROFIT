import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/goals/presentation/coach_goal_form/coach_goal_form_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeCoachGoalsRepository goals;

  CoachGoalFormViewModel build() => CoachGoalFormViewModel(
    repository: goals,
    client: testClient,
    clock: () => DateTime(2026, 10, 9, 15, 30),
  );

  void fillValidForm(CoachGoalFormViewModel viewModel) => viewModel
    ..setCalories('2200')
    ..setProtein('160')
    ..setFat('70');

  setUp(() => goals = FakeCoachGoalsRepository());

  test('la fecha de vigencia empieza en hoy', () {
    expect(build().effectiveFrom, DateTime(2026, 10, 9));
  });

  test('load trae el historial del cliente', () async {
    goals.history.add(testGoal());
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.history, hasLength(1));
    expect(viewModel.loadError, isNull);
  });

  test('load muestra el error si falla', () async {
    goals.historyError = networkError;
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.loadError, networkError.message);
  });

  test('campos vacíos o inválidos no se envían y se señalan', () async {
    final viewModel = build()
      ..setCalories('mucho')
      ..setFat('0');

    expect(await viewModel.submit(), isFalse);

    expect(goals.saved, isEmpty);
    expect(viewModel.fieldErrors.keys, {
      CoachGoalFormViewModel.caloriesField,
      CoachGoalFormViewModel.proteinField,
      CoachGoalFormViewModel.fatField,
    });
  });

  test(
    'meta válida: se guarda con la fecha elegida y recarga el historial',
    () async {
      final viewModel = build()..setEffectiveFrom(DateTime(2026, 10, 12, 8));
      fillValidForm(viewModel);

      expect(await viewModel.submit(), isTrue);

      final saved = goals.saved.single;
      expect(saved.clientId, testClient.id);
      expect((saved.calories, saved.proteinG, saved.fatG), (2200, 160, 70));
      expect(saved.effectiveFrom, DateTime(2026, 10, 12));
      expect(viewModel.history, hasLength(1));
    },
  );

  test('errores por campo del backend se muestran en su campo', () async {
    goals.setError = apiError(
      ApiErrorCode.validation,
      fields: {'effective_from': 'La fecha de vigencia no es válida'},
    );
    final viewModel = build();
    fillValidForm(viewModel);

    expect(await viewModel.submit(), isFalse);

    expect(
      viewModel.fieldError(CoachGoalFormViewModel.effectiveFromField),
      'La fecha de vigencia no es válida',
    );
    expect(viewModel.generalError, isNull);
  });

  test('un cliente desvinculado se muestra como error general', () async {
    goals.setError = apiError(
      ApiErrorCode.clientNotLinked,
      status: 403,
      message: 'No tienes una vinculación activa con este cliente',
    );
    final viewModel = build();
    fillValidForm(viewModel);

    expect(await viewModel.submit(), isFalse);

    expect(
      viewModel.generalError,
      'No tienes una vinculación activa con este cliente',
    );
  });

  test('editar un campo limpia su error', () async {
    final viewModel = build();
    await viewModel.submit();
    expect(
      viewModel.fieldError(CoachGoalFormViewModel.caloriesField),
      isNotNull,
    );

    viewModel.setCalories('2200');

    expect(viewModel.fieldError(CoachGoalFormViewModel.caloriesField), isNull);
  });
}
