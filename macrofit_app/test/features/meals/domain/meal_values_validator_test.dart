import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/meals/domain/validators/meal_values_validator.dart';

void main() {
  test('el 0 y los límites exactos son válidos', () {
    expect(MealValuesValidator.calories('0'), isNull);
    expect(MealValuesValidator.calories('10000'), isNull);
    expect(MealValuesValidator.protein('0'), isNull);
    expect(MealValuesValidator.protein('1000'), isNull);
    expect(MealValuesValidator.fat('0'), isNull);
    expect(MealValuesValidator.fat('1000'), isNull);
  });

  test('acepta decimales con punto o coma y espacios alrededor', () {
    expect(MealValuesValidator.protein(' 42.2 '), isNull);
    expect(MealValuesValidator.fat('4,9'), isNull);
    expect(MealValuesValidator.parse('4,9'), 4.9);
    expect(MealValuesValidator.parse(' 413 '), 413);
  });

  test('un valor vacío es obligatorio', () {
    expect(MealValuesValidator.calories(''), 'Las calorías son obligatorias');
    expect(MealValuesValidator.protein('  '), 'La proteína es obligatoria');
    expect(MealValuesValidator.fat(''), 'La grasa es obligatoria');
  });

  test('un texto que no es número se rechaza', () {
    for (final text in ['abc', '12g', '1.2.3', 'NaN', 'Infinity']) {
      expect(
        MealValuesValidator.calories(text),
        'Debe ser un número',
        reason: text,
      );
      expect(MealValuesValidator.parse(text), isNull, reason: text);
    }
  });

  test('los negativos se rechazan', () {
    expect(MealValuesValidator.calories('-1'), 'No puede ser negativo');
    expect(MealValuesValidator.protein('-0.5'), 'No puede ser negativo');
    expect(MealValuesValidator.fat('-3'), 'No puede ser negativo');
  });

  test('por encima del rango de la API se rechaza', () {
    expect(
      MealValuesValidator.calories('10000.1'),
      'No puede ser mayor a 10 000',
    );
    expect(MealValuesValidator.protein('1000.5'), 'No puede ser mayor a 1 000');
    expect(MealValuesValidator.fat('1001'), 'No puede ser mayor a 1 000');
  });
}
