import '../entities/profile.dart';

/// Reglas del perfil (HU-03). Deben coincidir con `backend/src/services/profile.rs`.
/// Cada función devuelve el mensaje de error o `null` si el valor es válido.
///
/// TODO(TEC-12): rangos provisionales; cambiarlos aquí y en el backend a la vez.
abstract final class ProfileValidators {
  static const weightMinKg = 30;
  static const weightMaxKg = 300;
  static const heightMinCm = 100;
  static const heightMaxCm = 250;
  static const ageMinYears = 18;
  static const ageMaxYears = 100;
  static const trainingDaysMin = 1;
  static const trainingDaysMax = 7;

  static String? objective(Objective? value) =>
      value == null ? 'Elige tu objetivo' : null;

  static String? level(ExperienceLevel? value) =>
      value == null ? 'Elige tu nivel' : null;

  static String? gender(Gender? value) =>
      value == null ? 'Elige tu sexo' : null;

  static String? trainingDays(int? value) {
    if (value == null) return 'Elige cuántos días entrenas';
    if (value < trainingDaysMin || value > trainingDaysMax) {
      return 'Los días de entrenamiento deben estar entre '
          '$trainingDaysMin y $trainingDaysMax';
    }
    return null;
  }

  static String? weight(String value) => _number(
    value,
    missing: 'El peso es obligatorio',
    min: weightMinKg,
    max: weightMaxKg,
    outOfRange: 'El peso debe estar entre $weightMinKg y $weightMaxKg kg',
  );

  static String? height(String value) => _number(
    value,
    missing: 'La estatura es obligatoria',
    min: heightMinCm,
    max: heightMaxCm,
    outOfRange: 'La estatura debe estar entre $heightMinCm y $heightMaxCm cm',
  );

  static String? birthDate(DateTime? value, {required DateTime today}) {
    if (value == null) return 'La fecha de nacimiento es obligatoria';
    final age = ageOn(value, today);
    if (age < 0) return 'La fecha de nacimiento no puede ser futura';
    if (age < ageMinYears || age > ageMaxYears) {
      return 'Debes tener entre $ageMinYears y $ageMaxYears años';
    }
    return null;
  }

  /// Convierte el texto del campo a número; acepta coma decimal (`72,5`).
  static double? parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  /// Años cumplidos a la fecha `today` (negativo si la fecha es futura).
  static int ageOn(DateTime birthDate, DateTime today) {
    if (DateTime(
      birthDate.year,
      birthDate.month,
      birthDate.day,
    ).isAfter(DateTime(today.year, today.month, today.day))) {
      return -1;
    }
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  static String? _number(
    String value, {
    required String missing,
    required num min,
    required num max,
    required String outOfRange,
  }) {
    if (value.trim().isEmpty) return missing;
    final number = parseNumber(value);
    if (number == null || !number.isFinite) return 'Escribe un número válido';
    if (number < min || number > max) return outOfRange;
    return null;
  }
}
