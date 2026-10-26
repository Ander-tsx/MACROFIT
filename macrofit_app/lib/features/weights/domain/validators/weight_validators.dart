/// Validador del peso (HU-21, TEC-12: 35 a 250 kg).
abstract final class WeightValidators {
  static const minKg = 35.0;
  static const maxKg = 250.0;

  static String? weight(String value) {
    if (value.trim().isEmpty) return 'El peso es obligatorio';
    final number = parseNumber(value);
    if (number == null || !number.isFinite) return 'Escribe un número válido';
    if (number < minKg || number > maxKg) {
      return 'El peso debe estar entre ${minKg.toInt()} y ${maxKg.toInt()} kg';
    }
    return null;
  }

  static double? parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
}
