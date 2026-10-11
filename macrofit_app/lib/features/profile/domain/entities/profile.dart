/// Objetivo del usuario. `apiValue` coincide con el valor de la API.
enum Objective {
  loseFat('lose_fat', 'Bajar grasa'),
  maintain('maintain', 'Mantener'),
  gainMuscle('gain_muscle', 'Ganar músculo');

  const Objective(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Objective fromApi(String value) => Objective.values.firstWhere(
    (objective) => objective.apiValue == value,
    orElse: () => throw FormatException('Objetivo desconocido: $value'),
  );
}

/// Nivel de entrenamiento. `apiValue` coincide con el valor de la API.
enum ExperienceLevel {
  beginner('beginner', 'Principiante'),
  intermediate('intermediate', 'Intermedio'),
  advanced('advanced', 'Avanzado');

  const ExperienceLevel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ExperienceLevel fromApi(String value) =>
      ExperienceLevel.values.firstWhere(
        (level) => level.apiValue == value,
        orElse: () => throw FormatException('Nivel desconocido: $value'),
      );
}

/// Sexo que usa el cálculo de la meta. `apiValue` coincide con el valor de la API.
enum Gender {
  male('male', 'Hombre'),
  female('female', 'Mujer');

  const Gender(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Gender fromApi(String value) => Gender.values.firstWhere(
    (gender) => gender.apiValue == value,
    orElse: () => throw FormatException('Sexo desconocido: $value'),
  );
}

/// Perfil inicial del usuario (HU-03). La fecha de nacimiento solo usa año, mes y día.
class Profile {
  const Profile({
    required this.objective,
    required this.level,
    required this.trainingDays,
    required this.weightKg,
    required this.heightCm,
    required this.gender,
    required this.birthDate,
  });

  final Objective objective;
  final ExperienceLevel level;

  /// Días de entrenamiento por semana (1 a 7).
  final int trainingDays;
  final double weightKg;
  final double heightCm;
  final Gender gender;
  final DateTime birthDate;

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.objective == objective &&
      other.level == level &&
      other.trainingDays == trainingDays &&
      other.weightKg == weightKg &&
      other.heightCm == heightCm &&
      other.gender == gender &&
      other.birthDate == birthDate;

  @override
  int get hashCode => Object.hash(
    objective,
    level,
    trainingDays,
    weightKg,
    heightCm,
    gender,
    birthDate,
  );
}
