import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/routines/domain/entities/routine.dart';
import 'package:macrofit_app/features/routines/presentation/routine_builder/routine_builder_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeRoutinesRepository repository;
  late RoutineBuilderViewModel viewModel;

  void create() {
    repository = FakeRoutinesRepository();
    viewModel = RoutineBuilderViewModel(repository: repository);
  }

  void edit(Routine routine) {
    repository = FakeRoutinesRepository();
    viewModel = RoutineBuilderViewModel(
      repository: repository,
      initial: routine,
    );
  }

  tearDown(() => viewModel.dispose());

  group('crear', () {
    setUp(create);

    test('empieza vacía y sin cambios', () {
      expect(viewModel.isEditing, isFalse);
      expect(viewModel.name, '');
      expect(viewModel.entries, isEmpty);
      expect(viewModel.hasChanges, isFalse);
    });

    test('los ejercicios agregados llegan con 3 × 10 y 60 s', () {
      viewModel.addExercises([testBenchPress, testRow]);

      expect(viewModel.entries.map((e) => e.exerciseId), [
        testBenchPress.id,
        testRow.id,
      ]);
      final entry = viewModel.entries.first;
      expect((entry.sets, entry.reps, entry.restSeconds), ('3', '10', '60'));
      expect(entry.name, testBenchPress.name);
      expect(viewModel.hasChanges, isTrue);
    });

    test(
      'guarda con POST el nombre recortado y los valores capturados',
      () async {
        viewModel
          ..setName('  Torso A ')
          ..addExercises([testBenchPress, testRow])
          ..setSets(0, '4')
          ..setReps(1, '12')
          ..setRestSeconds(1, '90');

        final saved = await viewModel.submit();

        expect(saved, isTrue);
        expect(
          repository.created.single,
          const RoutineDraft(
            name: 'Torso A',
            exercises: [
              RoutineExerciseDraft(
                exerciseId: '6ac6a0000000000000000001',
                sets: 4,
                reps: 10,
                restSeconds: 60,
              ),
              RoutineExerciseDraft(
                exerciseId: '6ac6a0000000000000000003',
                sets: 3,
                reps: 12,
                restSeconds: 90,
              ),
            ],
          ),
        );
        expect(repository.updated, isEmpty);
        expect(viewModel.saved?.name, 'Torso A');
        expect(viewModel.hasChanges, isFalse);
      },
    );

    test('una rutina guardada no se vuelve a enviar', () async {
      viewModel
        ..setName('Torso A')
        ..addExercises([testBenchPress]);
      await viewModel.submit();

      expect(await viewModel.submit(), isFalse);
      expect(repository.created, hasLength(1));
    });

    test('quitar un ejercicio lo saca de la rutina', () {
      viewModel
        ..addExercises([testBenchPress, testRow, testSquat])
        ..remove(1);

      expect(viewModel.entries.map((e) => e.exerciseId), [
        testBenchPress.id,
        testSquat.id,
      ]);
    });

    test('reordenar cambia el orden en que se guardan', () async {
      viewModel
        ..setName('Full body')
        ..addExercises([testBenchPress, testRow, testSquat])
        ..setSets(0, '5')
        ..move(0, 2);

      expect(viewModel.entries.map((e) => e.exerciseId), [
        testRow.id,
        testSquat.id,
        testBenchPress.id,
      ]);
      // El ejercicio conserva sus valores al moverse.
      expect(viewModel.entries.last.sets, '5');

      await viewModel.submit();
      expect(repository.created.single.exercises.map((e) => e.exerciseId), [
        testRow.id,
        testSquat.id,
        testBenchPress.id,
      ]);
    });

    test('se puede repetir un ejercicio', () {
      viewModel
        ..addExercises([testBenchPress])
        ..addExercises([testBenchPress]);

      expect(viewModel.entries, hasLength(2));
      expect(viewModel.entries[0].key, isNot(viewModel.entries[1].key));
    });

    test('no se pueden agregar más de 20 ejercicios', () {
      viewModel.addExercises(List.filled(19, testPushUps));
      expect(viewModel.canAddExercises, isTrue);

      viewModel.addExercises([testRow]);
      expect(viewModel.canAddExercises, isFalse);
    });
  });

  group('validación local (mismas reglas que HU-18-API)', () {
    setUp(create);

    test('sin nombre ni ejercicios no llama a la API (CU-04 4a)', () async {
      final saved = await viewModel.submit();

      expect(saved, isFalse);
      expect(viewModel.nameError, 'El nombre es obligatorio');
      expect(
        viewModel.exercisesError,
        'La rutina debe tener al menos un ejercicio',
      );
      expect(repository.created, isEmpty);
    });

    test('series y repeticiones en cero marcan su ejercicio', () async {
      viewModel
        ..setName('Torso A')
        ..addExercises([testBenchPress, testRow])
        ..setSets(1, '0')
        ..setReps(1, '0')
        ..setRestSeconds(0, '');

      await viewModel.submit();

      expect(
        viewModel.entryError(1, 'sets'),
        'Las series deben estar entre 1 y 10',
      );
      expect(
        viewModel.entryError(1, 'reps'),
        'Las repeticiones deben estar entre 1 y 100',
      );
      expect(
        viewModel.entryError(0, 'rest_seconds'),
        'El descanso es obligatorio',
      );
      expect(viewModel.entryError(0, 'sets'), isNull);
      expect(repository.created, isEmpty);
    });

    test('editar un campo limpia solo su error', () async {
      viewModel
        ..addExercises([testBenchPress])
        ..setSets(0, '0')
        ..setReps(0, '0');
      await viewModel.submit();

      viewModel
        ..setSets(0, '4')
        ..setName('Torso A');

      expect(viewModel.entryError(0, 'sets'), isNull);
      expect(viewModel.nameError, isNull);
      expect(viewModel.entryError(0, 'reps'), isNotNull);
    });

    test('quitar o reordenar limpia los errores de los ejercicios', () async {
      viewModel
        ..addExercises([testBenchPress, testRow])
        ..setSets(1, '0');
      await viewModel.submit();
      expect(viewModel.entryError(1, 'sets'), isNotNull);

      viewModel.move(1, 0);

      expect(viewModel.entryError(0, 'sets'), isNull);
      expect(viewModel.entryError(1, 'sets'), isNull);
      expect(viewModel.nameError, 'El nombre es obligatorio');
    });
  });

  group('errores de la API', () {
    setUp(create);

    void fill() => viewModel
      ..setName('Torso A')
      ..addExercises([testBenchPress, testRow]);

    test('un 400 marca cada campo, incluido un ejercicio fuera del catálogo '
        '(CU-04 4a y 5a)', () async {
      fill();
      repository.saveError = apiError(
        ApiErrorCode.validation,
        fields: {
          'name': 'El nombre debe tener máximo 80 caracteres',
          'exercises[1].exercise_id': 'El ejercicio no existe en el catálogo',
          'exercises[0].reps': 'Las repeticiones deben estar entre 1 y 100',
        },
      );

      final saved = await viewModel.submit();

      expect(saved, isFalse);
      expect(viewModel.nameError, 'El nombre debe tener máximo 80 caracteres');
      expect(
        viewModel.entryGeneralError(1),
        'El ejercicio no existe en el catálogo',
      );
      expect(
        viewModel.entryError(0, 'reps'),
        'Las repeticiones deben estar entre 1 y 100',
      );
      expect(viewModel.generalError, isNull);
      expect(viewModel.entries, hasLength(2), reason: 'conserva lo capturado');
    });

    test('un 400 sin campos conocidos se muestra como error general', () async {
      fill();
      repository.saveError = apiError(
        ApiErrorCode.invalidBody,
        message: 'El cuerpo no es válido',
      );

      await viewModel.submit();

      expect(viewModel.generalError, 'El cuerpo no es válido');
    });

    test('sin red muestra el mensaje y permite volver a guardar', () async {
      fill();
      repository.saveError = networkError;

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.generalError, networkError.message);
      expect(viewModel.isSubmitting, isFalse);

      repository.saveError = null;
      expect(await viewModel.submit(), isTrue);
      expect(repository.created, hasLength(2));
    });
  });

  group('editar', () {
    test('precarga el nombre y los ejercicios de la rutina', () {
      edit(testRoutine);

      expect(viewModel.isEditing, isTrue);
      expect(viewModel.name, 'Torso A');
      expect(
        viewModel.entries.map((e) => (e.name, e.sets, e.reps, e.restSeconds)),
        [
          ('Press de banca con mancuernas', '4', '10', '90'),
          ('Remo con barra', '3', '12', '60'),
        ],
      );
      expect(viewModel.hasChanges, isFalse);
    });

    test('guarda los cambios con PUT a su id', () async {
      edit(testRoutine);
      viewModel
        ..setName('Torso B')
        ..remove(1)
        ..addExercises([testPushUps]);

      final saved = await viewModel.submit();

      expect(saved, isTrue);
      expect(repository.created, isEmpty);
      final update = repository.updated.single;
      expect(update.id, testRoutine.id);
      expect(update.draft.name, 'Torso B');
      expect(update.draft.exercises.map((e) => e.exerciseId), [
        testBenchPress.id,
        testPushUps.id,
      ]);
      expect(viewModel.saved?.name, 'Torso B');
    });

    test('volver al valor original ya no cuenta como cambio', () {
      edit(testRoutine);

      viewModel.setSets(0, '5');
      expect(viewModel.hasChanges, isTrue);

      viewModel.setSets(0, '4');
      expect(viewModel.hasChanges, isFalse);
    });

    test('una rutina que ya no existe (404) muestra el mensaje', () async {
      edit(testRoutine);
      repository.saveError = apiError(
        ApiErrorCode.routineNotFound,
        status: 404,
        message: 'La rutina no existe',
      );

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.generalError, 'La rutina no existe');
    });
  });
}
