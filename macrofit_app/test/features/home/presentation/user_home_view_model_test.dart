import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view_model.dart';
import 'package:macrofit_app/features/summary/domain/entities/macro_values.dart';

import '../../../helpers/fakes.dart';

void main() {
  UserHomeViewModel createViewModel(
    FakeGoalsRepository goals, {
    FakeSummaryRepository? summary,
    DateTime Function()? clock,
  }) => UserHomeViewModel(
    auth: FakeAuthRepository(initialState: const Authenticated(testUser)),
    goals: goals,
    summary: summary ?? FakeSummaryRepository(),
    clock: clock ?? DateTime.now,
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

  group('resumen del día (HU-10)', () {
    test('loadSummary trae el consumo, la meta y lo que falta', () async {
      final viewModel = createViewModel(FakeGoalsRepository());

      await viewModel.loadSummary();

      final summary = viewModel.daySummary!;
      expect(summary.consumed.caloriesKcal, 1050.5);
      expect(summary.goal.caloriesKcal, 2200);
      expect(summary.remaining.caloriesKcal, 1149.5);
      expect(viewModel.hasNoSummary, isFalse);
      expect(viewModel.summaryError, isNull);
      expect(viewModel.isLoadingSummary, isFalse);
    });

    test(
      'un día sin registros trae consumo en 0 y restante igual a la meta',
      () async {
        final summaries = FakeSummaryRepository(
          daily: testDaySummary(
            consumed: const MacroValues(caloriesKcal: 0, proteinG: 0, fatG: 0),
          ),
        );
        final viewModel = createViewModel(
          FakeGoalsRepository(),
          summary: summaries,
        );

        await viewModel.loadSummary();

        final summary = viewModel.daySummary!;
        expect(summary.consumed.caloriesKcal, 0);
        expect(summary.consumed.proteinG, 0);
        expect(summary.consumed.fatG, 0);
        expect(summary.remaining.caloriesKcal, summary.goal.caloriesKcal);
        expect(summary.remaining.proteinG, summary.goal.proteinG);
        expect(summary.remaining.fatG, summary.goal.fatG);
      },
    );

    test('con exceso el restante es negativo', () async {
      final summaries = FakeSummaryRepository(
        daily: testDaySummary(
          consumed: const MacroValues(
            caloriesKcal: 2350,
            proteinG: 100,
            fatG: 70,
          ),
        ),
      );
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
      );

      await viewModel.loadSummary();

      expect(viewModel.daySummary!.remaining.caloriesKcal, -150);
    });

    test('pide el día de hoy en hora de México, no el UTC', () async {
      final summaries = FakeSummaryRepository();
      // 02:30 UTC del 17 de octubre es todavía el 16 a las 20:30 en México (UTC-6).
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
        clock: () => DateTime.utc(2026, 10, 17, 2, 30),
      );

      await viewModel.loadSummary();

      expect(summaries.dailyDates, ['2026-10-16']);
    });

    test('sin meta (404 PROFILE_NOT_FOUND) no se considera un error', () async {
      final viewModel = createViewModel(
        FakeGoalsRepository.withoutGoal(),
        summary: FakeSummaryRepository.withoutGoal(),
      );

      await viewModel.loadSummary();

      expect(viewModel.daySummary, isNull);
      expect(viewModel.hasNoSummary, isTrue);
      expect(viewModel.summaryError, isNull);
    });

    test('antes de cargar no se considera que falte el resumen', () {
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: FakeSummaryRepository.withoutGoal(),
      );
      expect(viewModel.hasNoSummary, isFalse);
      expect(viewModel.daySummary, isNull);
    });

    test('sin conexión muestra el error y permite reintentar', () async {
      final summaries = FakeSummaryRepository()..error = networkError;
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
      );

      await viewModel.loadSummary();
      expect(viewModel.summaryError, networkError.message);
      expect(viewModel.daySummary, isNull);
      expect(viewModel.hasNoSummary, isFalse);

      summaries.error = null;
      await viewModel.loadSummary();
      expect(viewModel.summaryError, isNull);
      expect(viewModel.daySummary, isNotNull);
      expect(summaries.dailyDates, hasLength(2));
    });

    test('un error al recargar conserva el último resumen', () async {
      final summaries = FakeSummaryRepository();
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
      );
      await viewModel.loadSummary();

      summaries.error = networkError;
      await viewModel.loadSummary();

      expect(viewModel.summaryError, networkError.message);
      expect(viewModel.daySummary?.consumed.caloriesKcal, 1050.5);
    });

    test('al recargar refleja los registros nuevos', () async {
      final summaries = FakeSummaryRepository();
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
      );
      await viewModel.loadSummary();

      summaries.daily = testDaySummary(
        consumed: const MacroValues(caloriesKcal: 1500, proteinG: 90, fatG: 50),
      );
      await viewModel.loadSummary();

      expect(viewModel.daySummary?.consumed.caloriesKcal, 1500);
    });

    test('no lanza una segunda consulta mientras otra está en curso', () async {
      final summaries = FakeSummaryRepository()..gate = Completer<void>();
      final viewModel = createViewModel(
        FakeGoalsRepository(),
        summary: summaries,
      );

      final first = viewModel.loadSummary();
      expect(viewModel.isLoadingSummary, isTrue);
      unawaited(viewModel.loadSummary());
      summaries.gate!.complete();
      await first;

      expect(summaries.dailyDates, hasLength(1));
      expect(viewModel.isLoadingSummary, isFalse);
    });

    test('refresh consulta la meta y el resumen', () async {
      final goals = FakeGoalsRepository();
      final summaries = FakeSummaryRepository();
      final viewModel = createViewModel(goals, summary: summaries);

      await viewModel.refresh();

      expect(goals.currentCalls, 1);
      expect(summaries.dailyDates, hasLength(1));
    });
  });
}
