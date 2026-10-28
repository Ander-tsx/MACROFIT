/// Reglas de los valores de un registro de comida (HU-08, RF-07). Deben
/// coincidir con `backend/src/services/meals.rs` (`parse_amount`, `CALORIES_MAX`,
/// `MACRO_MAX_G`). Cada función devuelve el mensaje de error o `null` si es válido.
abstract final class MealValuesValidator {
  static const caloriesMax = 10000.0;
  static const macroMaxG = 1000.0;

  static String? calories(String value) => _amount(
    value,
    missing: 'Las calorías son obligatorias',
    max: caloriesMax,
    maxText: '10 000',
  );

  static String? protein(String value) => _amount(
    value,
    missing: 'La proteína es obligatoria',
    max: macroMaxG,
    maxText: '1 000',
  );

  static String? fat(String value) => _amount(
    value,
    missing: 'La grasa es obligatoria',
    max: macroMaxG,
    maxText: '1 000',
  );

  /// Convierte el texto del campo a número (acepta coma decimal: `4,9`);
  /// `null` si no es un número finito.
  static double? parse(String value) {
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    return number != null && number.isFinite ? number : null;
  }

  static String? _amount(
    String value, {
    required String missing,
    required double max,
    required String maxText,
  }) {
    if (value.trim().isEmpty) return missing;
    final number = parse(value);
    if (number == null) return 'Debe ser un número';
    if (number < 0) return 'No puede ser negativo';
    if (number > max) return 'No puede ser mayor a $maxText';
    return null;
  }
}
