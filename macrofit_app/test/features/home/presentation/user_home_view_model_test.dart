import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  UserHomeViewModel createViewModel(FakeGoalsRepository goals) =>
      UserHomeViewModel(
        auth: FakeAuthRepository(initialState: const Authenticated(testUser)),
        goals: goals,
      );

  test('loadGoal trae la meta calculada por el sistema', () async {
    final viewModel = createViewModel(
      FakeGoalsRepository(
        current: testGoal(
          calories: 1900,
          proteinG: 130,
          fatG: 60,
          source: GoalSource.system,
        ),
      ),
    );

    await viewModel.loadGoal();

    expect(viewModel.goal?.calories, 1900);
    expect(viewModel.goal?.proteinG, 130);
    expect(viewModel.goal?.fatG, 60);
    expect(viewModel.goal?.source, GoalSource.system);
    expect(viewModel.hasNoGoal, isFalse);
    expect(viewModel.goalError, isNull);
    expect(viewModel.isLoadingGoal, isFalse);
  });

  test('loadGoal trae la meta definida por el coach', () async {
    final viewModel = createViewModel(
      FakeGoalsRepository(current: testGoal(source: GoalSource.coach)),
    );

    await viewModel.loadGoal();

    expect(viewModel.goal?.source, GoalSource.coach);
    expect(viewModel.goal?.calories, 2200);
  });

  test('sin meta (404 PROFILE_NOT_FOUND) no se considera un error', () async {
    final viewModel = createViewModel(FakeGoalsRepository.withoutGoal());

    await viewModel.loadGoal();

    expect(viewModel.goal, isNull);
    expect(viewModel.hasNoGoal, isTrue);
    expect(viewModel.goalError, isNull);
  });

  test('antes de cargar no se considera que no haya meta', () {
    final viewModel = createViewModel(FakeGoalsRepository.withoutGoal());
    expect(viewModel.hasNoGoal, isFalse);
    expect(viewModel.goal, isNull);
  });

  test('sin conexión muestra el error y permite reintentar', () async {
    final goals = FakeGoalsRepository()..error = networkError;
    final viewModel = createViewModel(goals);

    await viewModel.loadGoal();
    expect(viewModel.goalError, networkError.message);
    expect(viewModel.goal, isNull);
    expect(viewModel.hasNoGoal, isFalse);

    goals.error = null;
    await viewModel.loadGoal();
    expect(viewModel.goalError, isNull);
    expect(viewModel.goal, isNotNull);
    expect(goals.currentCalls, 2);
  });

  test('un error al recargar conserva la última meta', () async {
    final goals = FakeGoalsRepository();
    final viewModel = createViewModel(goals);
    await viewModel.loadGoal();

    goals.error = networkError;
    await viewModel.loadGoal();

    expect(viewModel.goalError, networkError.message);
    expect(viewModel.goal?.calories, 2200);
  });

  test('al recargar refleja la meta recalculada (HU-04)', () async {
    final goals = FakeGoalsRepository();
    final viewModel = createViewModel(goals);
    await viewModel.loadGoal();

    goals.current = testGoal(calories: 2500, source: GoalSource.system);
    await viewModel.loadGoal();

    expect(viewModel.goal?.calories, 2500);
  });

  test('no lanza una segunda consulta mientras otra está en curso', () async {
    final goals = FakeGoalsRepository()..gate = Completer<void>();
    final viewModel = createViewModel(goals);

    final first = viewModel.loadGoal();
    expect(viewModel.isLoadingGoal, isTrue);
    unawaited(viewModel.loadGoal());
    goals.gate!.complete();
    await first;

    expect(goals.currentCalls, 1);
    expect(viewModel.isLoadingGoal, isFalse);
  });
}
