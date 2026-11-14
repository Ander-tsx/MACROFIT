import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/routines/domain/entities/exercise.dart';
import 'package:macrofit_app/features/routines/presentation/exercise_picker/exercise_picker_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeRoutinesRepository repository;
  late ExercisePickerViewModel viewModel;

  setUp(() {
    repository = FakeRoutinesRepository();
    viewModel = ExercisePickerViewModel(repository);
  });

  tearDown(() => viewModel.dispose());

  test('carga el catálogo completo sin filtros', () async {
    await viewModel.load();

    expect(viewModel.exercises, testExercises);
    expect(repository.exerciseRequests.single, (
      muscleGroup: null,
      level: null,
    ));
  });

  test('filtra por grupo muscular y nivel con GET /exercises', () async {
    await viewModel.load();

    await viewModel.setMuscleGroup(MuscleGroup.chest);
    expect(viewModel.exercises, [testBenchPress, testPushUps]);

    await viewModel.setLevel(ExerciseLevel.intermediate);
    expect(viewModel.exercises, isEmpty);
    expect(viewModel.hasNoResults, isTrue);

    await viewModel.setMuscleGroup(null);
    expect(viewModel.exercises, [testRow]);
    expect(repository.exerciseRequests.last, (
      muscleGroup: null,
      level: ExerciseLevel.intermediate,
    ));
  });

  test('elegir el mismo filtro no vuelve a consultar', () async {
    await viewModel.setMuscleGroup(MuscleGroup.back);
    await viewModel.setMuscleGroup(MuscleGroup.back);

    expect(repository.exerciseRequests, hasLength(1));
  });

  test('selección múltiple en el orden en que se marcan', () async {
    await viewModel.load();

    viewModel
      ..toggle(testRow)
      ..toggle(testBenchPress)
      ..toggle(testSquat)
      ..toggle(testSquat);

    expect(viewModel.selected, [testRow, testBenchPress]);
    expect(viewModel.selectedCount, 2);
    expect(viewModel.isSelected(testSquat), isFalse);
  });

  test('la selección se conserva al cambiar de filtro', () async {
    await viewModel.load();
    viewModel.toggle(testSquat);

    await viewModel.setMuscleGroup(MuscleGroup.chest);
    viewModel.toggle(testPushUps);

    expect(viewModel.selected, [testSquat, testPushUps]);
  });

  test('sin red muestra el error y reintentar vuelve a consultar', () async {
    repository.exercisesError = networkError;
    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.hasNoResults, isFalse);

    repository.exercisesError = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.exercises, testExercises);
  });

  test('descarta la respuesta de un filtro anterior', () async {
    repository.exercisesGate = Completer<void>();
    final first = viewModel.load();
    final second = viewModel.setMuscleGroup(MuscleGroup.legs);
    expect(viewModel.isLoading, isTrue);

    repository.exercisesGate!.complete();
    await Future.wait([first, second]);

    expect(viewModel.exercises, [testSquat]);
    expect(viewModel.isLoading, isFalse);
  });
}
