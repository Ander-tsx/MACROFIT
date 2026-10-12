import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/goals/domain/validators/coach_goal_validators.dart';

void main() {
  group('calorías', () {
    test('acepta enteros dentro del rango', () {
      for (final value in ['1', ' 2200 ', '10000']) {
        expect(CoachGoalValidators.calories(value), isNull, reason: value);
      }
    });

    test('rechaza vacío, texto, decimales, cero, negativos y excesos', () {
      expect(CoachGoalValidators.calories(''), 'Las calorías son obligatorias');
      for (final value in ['mucho', '22.5', '0', '-5', '10001']) {
        expect(CoachGoalValidators.calories(value), isNotNull, reason: value);
      }
    });
  });

  test('proteína y grasa comparten el rango de macros', () {
    expect(CoachGoalValidators.protein('1000'), isNull);
    expect(CoachGoalValidators.fat('1000'), isNull);
    expect(
      CoachGoalValidators.protein('1001'),
      'La proteína debe estar entre 1 y 1000',
    );
    expect(CoachGoalValidators.fat(''), 'La grasa es obligatoria');
  });

  test('parse convierte texto a entero', () {
    expect(CoachGoalValidators.parse(' 160 '), 160);
    expect(CoachGoalValidators.parse('1.5'), isNull);
  });
}
