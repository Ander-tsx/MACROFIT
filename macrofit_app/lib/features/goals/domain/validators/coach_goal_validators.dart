/// Reglas de la meta del coach (HU-05). Deben coincidir con `backend/src/services/goals.rs`.
/// Cada función devuelve el mensaje de error o `null` si el valor es válido.
abstract final class CoachGoalValidators {
  static const caloriesMax = 10000;
  static const macroMaxG = 1000;

  static String? calories(String value) => _integer(
    value,
    label: 'Las calorías',
    missing: 'Las calorías son obligatorias',
    max: caloriesMax,
  );

  static String? protein(String value) => _integer(
    value,
    label: 'La proteína',
    missing: 'La proteína es obligatoria',
    max: macroMaxG,
  );

  static String? fat(String value) => _integer(
    value,
    label: 'La grasa',
    missing: 'La grasa es obligatoria',
    max: macroMaxG,
  );

  /// Convierte el texto del campo a entero; `null` si no lo es.
  static int? parse(String value) => int.tryParse(value.trim());

  static String? _integer(
    String value, {
    required String label,
    required String missing,
    required int max,
  }) {
    if (value.trim().isEmpty) return missing;
    final number = parse(value);
    if (number == null) return '$label debe ser un número entero';
    if (number < 1 || number > max) return '$label debe estar entre 1 y $max';
    return null;
  }
}
