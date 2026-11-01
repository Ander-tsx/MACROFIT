import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/summary/presentation/weekly_summary/weekly_summary_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  // 22 de octubre de 2026, 12:00 en México (18:00 UTC).
  final now = DateTime.utc(2026, 10, 22, 18);

  WeeklySummaryViewModel createViewModel(FakeSummaryRepository repository) =>
      WeeklySummaryViewModel(repository: repository, clock: () => now);

  test('la semana inicial termina hoy', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);

    await viewModel.load();

    expect(viewModel.start, '2026-10-16');
    expect(viewModel.end, '2026-10-22');
    expect(repository.weeklyStarts, ['2026-10-16']);
  });

  test('hoy se toma en hora de México, no en UTC', () async {
    // 03:00 UTC del 23 es todavía el 22 a las 21:00 en México.
    final viewModel = WeeklySummaryViewModel(
      repository: FakeSummaryRepository(),
      clock: () => DateTime.utc(2026, 10, 23, 3),
    );

    expect(viewModel.today, '2026-10-22');
    expect(viewModel.end, '2026-10-22');
  });

  test(
    'con registros trae los 7 días, el promedio y los días cumplidos',
    () async {
      final viewModel = createViewModel(FakeSummaryRepository());

      await viewModel.load();

      final summary = viewModel.summary!;
      expect(summary.days, hasLength(7));
      expect(summary.days.where((day) => day.goalMet), hasLength(5));
      expect(summary.goalMetDays, 5);
      expect(summary.average.caloriesKcal, 1700);
      expect(viewModel.hasNoSummary, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    },
  );

  test(
    'una semana sin registros trae los 7 días en 0 sin días cumplidos',
    () async {
      final viewModel = createViewModel(
        FakeSummaryRepository(weekly: testEmptyWeekSummary()),
      );

      await viewModel.load();

      final summary = viewModel.summary!;
      expect(summary.days, hasLength(7));
      expect(
        summary.days.every((day) => day.consumed.caloriesKcal == 0),
        isTrue,
      );
      expect(summary.days.every((day) => !day.goalMet), isTrue);
      expect(summary.goalMetDays, 0);
    },
  );

  test('la semana siguiente no puede terminar después de hoy', () async {
    final viewModel = createViewModel(FakeSummaryRepository());
    await viewModel.load();

    expect(viewModel.canGoForward, isFalse);
  });

  test('previousWeek va 7 días atrás y vuelve a consultar', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);
    await viewModel.load();

    await viewModel.previousWeek();

    expect(viewModel.start, '2026-10-09');
    expect(viewModel.end, '2026-10-15');
    expect(repository.weeklyStarts, ['2026-10-16', '2026-10-09']);
    expect(viewModel.summary!.start, '2026-10-09');
    expect(viewModel.canGoForward, isTrue);
  });

  test('nextWeek regresa a la semana siguiente y se detiene en hoy', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);
    await viewModel.load();
    await viewModel.previousWeek();
    await viewModel.previousWeek();

    await viewModel.nextWeek();
    await viewModel.nextWeek();
    await viewModel.nextWeek();

    expect(viewModel.start, '2026-10-16');
    expect(repository.weeklyStarts, [
      '2026-10-16',
      '2026-10-09',
      '2026-10-02',
      '2026-10-09',
      '2026-10-16',
    ]);
  });

  test('al cambiar de semana se quita la anterior mientras carga', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);
    await viewModel.load();

    repository.gate = Completer<void>();
    final moving = viewModel.previousWeek();

    expect(viewModel.isLoading, isTrue);
    expect(viewModel.summary, isNull);
    repository.gate!.complete();
    await moving;
    expect(viewModel.summary, isNotNull);
  });

  test('sin meta (404 PROFILE_NOT_FOUND) no se considera un error', () async {
    final viewModel = createViewModel(FakeSummaryRepository.withoutGoal());

    await viewModel.load();

    expect(viewModel.summary, isNull);
    expect(viewModel.hasNoSummary, isTrue);
    expect(viewModel.error, isNull);
  });

  test('antes de cargar no se considera que falte el resumen', () {
    final viewModel = createViewModel(FakeSummaryRepository.withoutGoal());
    expect(viewModel.hasNoSummary, isFalse);
  });

  test('sin conexión muestra el error y permite reintentar', () async {
    final repository = FakeSummaryRepository()..error = networkError;
    final viewModel = createViewModel(repository);

    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.summary, isNull);

    repository.error = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.summary, isNotNull);
  });

  test('un error al recargar la misma semana conserva el resumen', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);
    await viewModel.load();

    repository.error = networkError;
    await viewModel.load();

    expect(viewModel.error, networkError.message);
    expect(viewModel.summary, isNotNull);
  });

  test('un error al cambiar de semana no deja la semana anterior bajo otras fechas', () async {
    final repository = FakeSummaryRepository();
    final viewModel = createViewModel(repository);
    await viewModel.load();

    repository.error = networkError;
    await viewModel.previousWeek();

    expect(viewModel.start, '2026-10-09');
    expect(viewModel.summary, isNull);
    expect(viewModel.error, networkError.message);
  });

  test('no lanza una segunda consulta mientras otra está en curso', () async {
    final repository = FakeSummaryRepository()..gate = Completer<void>();
    final viewModel = createViewModel(repository);

    final first = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    unawaited(viewModel.load());
    repository.gate!.complete();
    await first;

    expect(repository.weeklyStarts, hasLength(1));
  });

  test('la respuesta de una semana que ya no se ve se descarta', () async {
    final repository = FakeSummaryRepository()..gate = Completer<void>();
    final viewModel = createViewModel(repository);

    final first = viewModel.load();
    final second = viewModel.previousWeek();
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(viewModel.start, '2026-10-09');
    expect(viewModel.summary!.start, '2026-10-09');
  });
}
