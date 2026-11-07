import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/my_routines/domain/entities/user_routine.dart';
import 'package:macrofit_app/features/my_routines/presentation/routine_detail/routine_detail_view_model.dart';
import 'package:macrofit_app/features/my_routines/presentation/widgets/my_routine_texts.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('carga las sesiones de la rutina recomendada', () async {
    final viewModel = RoutineDetailViewModel(
      repository: FakeMyRoutinesRepository(
        routines: [testRecommendedRoutine()],
      ),
      routineId: 'rec1',
    );

    await viewModel.load();

    final routine = viewModel.routine!;
    expect(routine.sessions.map((s) => s.name), [
      'Día 1 · Cuerpo completo',
      'Día 2 · Cuerpo completo',
      'Día 3 · Cuerpo completo',
    ]);
    expect(viewModel.title, routine.name);
  });

  test('la asignada tiene una sola sesión con su volumen', () async {
    final viewModel = RoutineDetailViewModel(
      repository: FakeMyRoutinesRepository(routines: [testAssignedRoutine()]),
      routineId: 'asg1',
    );

    await viewModel.load();

    final exercise = viewModel.routine!.sessions.single.exercises.single;
    expect(
      exerciseVolumeText(exercise),
      '4 series × 10 reps · 90 s de descanso',
    );
    expect(viewModel.routine!.coachName, 'Carlos');
  });

  test('mientras carga usa el título de la lista', () {
    final viewModel = RoutineDetailViewModel(
      repository: FakeMyRoutinesRepository(),
      routineId: 'asg1',
      summary: testAssignedRoutine().toSummary(),
    );

    expect(viewModel.title, 'Torso A');
  });

  test(
    'una rutina retirada queda no disponible y se avisa una sola vez',
    () async {
      final viewModel = RoutineDetailViewModel(
        repository: FakeMyRoutinesRepository(),
        routineId: 'retirada',
      );

      await viewModel.load();

      expect(viewModel.isUnavailable, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.takeUnavailable(), isTrue);
      expect(viewModel.takeUnavailable(), isFalse);
    },
  );

  test('sin conexión muestra el error y permite reintentar', () async {
    final repository = FakeMyRoutinesRepository(
      routines: [testAssignedRoutine()],
    )..detailError = networkError;
    final viewModel = RoutineDetailViewModel(
      repository: repository,
      routineId: 'asg1',
    );

    await viewModel.load();
    expect(viewModel.error, 'Sin conexión');
    expect(viewModel.isUnavailable, isFalse);

    repository.detailError = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.routine?.origin, RoutineOrigin.coach);
  });

  test('textos de origen y número de sesiones', () {
    expect(originLabel(RoutineOrigin.system, null), 'Recomendada');
    expect(originLabel(RoutineOrigin.coach, 'Carlos'), 'Asignada por Carlos');
    expect(originLabel(RoutineOrigin.coach, ' '), 'Asignada por tu coach');
    expect(sessionCountText(1), '1 sesión');
    expect(sessionCountText(3), '3 sesiones');
    expect(muscleGroupText('legs'), 'Piernas');
  });
}
