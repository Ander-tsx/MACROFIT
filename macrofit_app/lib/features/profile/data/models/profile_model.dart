import '../../domain/entities/profile.dart';

/// Representación JSON del perfil (`ProfileResponse` del backend).
class ProfileModel {
  const ProfileModel({
    required this.objective,
    required this.level,
    required this.trainingDays,
    required this.weightKg,
    required this.heightCm,
    required this.gender,
    required this.birthDate,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    objective: json['objective'] as String,
    level: json['level'] as String,
    trainingDays: (json['training_days'] as num).toInt(),
    weightKg: (json['weight_kg'] as num).toDouble(),
    heightCm: (json['height_cm'] as num).toDouble(),
    gender: json['gender'] as String,
    birthDate: json['birth_date'] as String,
  );

  factory ProfileModel.fromEntity(Profile profile) => ProfileModel(
    objective: profile.objective.apiValue,
    level: profile.level.apiValue,
    trainingDays: profile.trainingDays,
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    gender: profile.gender.apiValue,
    birthDate: formatDate(profile.birthDate),
  );

  final String objective;
  final String level;
  final int trainingDays;
  final double weightKg;
  final double heightCm;
  final String gender;

  /// `YYYY-MM-DD`.
  final String birthDate;

  Map<String, dynamic> toJson() => {
    'objective': objective,
    'level': level,
    'training_days': trainingDays,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'gender': gender,
    'birth_date': birthDate,
  };

  Profile toEntity() => Profile(
    objective: Objective.fromApi(objective),
    level: ExperienceLevel.fromApi(level),
    trainingDays: trainingDays,
    weightKg: weightKg,
    heightCm: heightCm,
    gender: Gender.fromApi(gender),
    birthDate: parseDate(birthDate),
  );

  /// `DateTime` → `YYYY-MM-DD` (solo año, mes y día).
  static String formatDate(DateTime date) {
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    return '${pad(date.year, 4)}-${pad(date.month, 2)}-${pad(date.day, 2)}';
  }

  /// `YYYY-MM-DD` → `DateTime` local a medianoche.
  static DateTime parseDate(String value) {
    final [year, month, day] = value.split('-').map(int.parse).toList();
    return DateTime(year, month, day);
  }
}
