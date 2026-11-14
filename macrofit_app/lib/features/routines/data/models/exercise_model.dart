import '../../domain/entities/exercise.dart';

/// Un elemento de `GET /exercises` (TEC-09).
class ExerciseModel extends Exercise {
  const ExerciseModel({
    required super.id,
    required super.name,
    required super.muscleGroup,
    required super.equipment,
    required super.level,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) => ExerciseModel(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleGroup: json['muscle_group'] as String,
    equipment: json['equipment'] as String? ?? '',
    level: json['level'] as String? ?? '',
  );
}
