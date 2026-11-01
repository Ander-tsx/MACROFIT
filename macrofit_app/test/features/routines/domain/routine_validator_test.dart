import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/routines/domain/validators/routine_validator.dart';

void main() {
  ({String sets, String reps, String restSeconds}) item({
    String sets = '3',
    String reps = '10',
    String rest = '60',
  }) => (sets: sets, reps: reps, restSeconds: rest);

  group('nombre', () {
    test('es obligatorio (vacío o solo espacios)', () {
      expect(RoutineValidator.name(''), 'El nombre es obligatorio');
      expect(RoutineValidator.name('   '), 'El nombre es obligatorio');
    });

    test('acepta hasta 80 caracteres sin contar los espacios alrededor', () {
      expect(RoutineValidator.name('Torso A'), isNull);
      expect(RoutineValidator.name('  ${'a' * 80}  '), isNull);
      expect(
        RoutineValidator.name('a' * 81),
        'El nombre debe tener máximo 80 caracteres',
      );
    });
  });

  test('exige de 1 a 20 ejercicios', () {
    expect(
      RoutineValidator.exerciseCount(0),
      'La rutina debe tener al menos un ejercicio',
    );
    expect(RoutineValidator.exerciseCount(1), isNull);
    expect(RoutineValidator.exerciseCount(20), isNull);
    expect(
      RoutineValidator.exerciseCount(21),
      'La rutina puede tener máximo 20 ejercicios',
    );
  });

  test('series: entero de 1 a 10 (mayor a cero)', () {
    expect(RoutineValidator.sets(''), 'Las series son obligatorias');
    expect(RoutineValidator.sets('0'), 'Las series deben estar entre 1 y 10');
    expect(RoutineValidator.sets('-2'), 'Las series deben estar entre 1 y 10');
    expect(RoutineValidator.sets('11'), 'Las series deben estar entre 1 y 10');
    expect(
      RoutineValidator.sets('2.5'),
      'Las series deben ser un número entero',
    );
    expect(
      RoutineValidator.sets('tres'),
      'Las series deben ser un número entero',
    );
    expect(RoutineValidator.sets('1'), isNull);
    expect(RoutineValidator.sets(' 10 '), isNull);
  });

  test('repeticiones: entero de 1 a 100 (mayor a cero)', () {
    expect(RoutineValidator.reps(''), 'Las repeticiones son obligatorias');
    expect(
      RoutineValidator.reps('0'),
      'Las repeticiones deben estar entre 1 y 100',
    );
    expect(
      RoutineValidator.reps('101'),
      'Las repeticiones deben estar entre 1 y 100',
    );
    expect(RoutineValidator.reps('1'), isNull);
    expect(RoutineValidator.reps('100'), isNull);
  });

  test('descanso: entero de 0 a 600 segundos', () {
    expect(RoutineValidator.restSeconds(''), 'El descanso es obligatorio');
    expect(
      RoutineValidator.restSeconds('-1'),
      'El descanso debe estar entre 0 y 600 segundos',
    );
    expect(
      RoutineValidator.restSeconds('601'),
      'El descanso debe estar entre 0 y 600 segundos',
    );
    expect(RoutineValidator.restSeconds('0'), isNull);
    expect(RoutineValidator.restSeconds('600'), isNull);
  });

  group('validate', () {
    test('una rutina válida no tiene errores', () {
      expect(
        RoutineValidator.validate(name: 'Torso A', exercises: [item()]),
        isEmpty,
      );
    });

    test('reporta todos los errores a la vez con los nombres de la API', () {
      final errors = RoutineValidator.validate(
        name: ' ',
        exercises: [
          item(),
          item(sets: '0', reps: '', rest: '700'),
        ],
      );

      expect(errors, {
        'name': 'El nombre es obligatorio',
        'exercises[1].sets': 'Las series deben estar entre 1 y 10',
        'exercises[1].reps': 'Las repeticiones son obligatorias',
        'exercises[1].rest_seconds':
            'El descanso debe estar entre 0 y 600 segundos',
      });
    });

    test('sin ejercicios marca la lista (CU-04 4a)', () {
      expect(RoutineValidator.validate(name: 'Torso A', exercises: []), {
        'exercises': 'La rutina debe tener al menos un ejercicio',
      });
    });
  });
}
