import '../../domain/entities/nutritional_goal.dart';

class GoalModel extends NutritionalGoal {
  const GoalModel({
    super.id,
    required super.userId,
    required super.calories,
    required super.proteinG,
    required super.fatG,
    required super.carbsG,
    required super.source,
    super.setBy,
    required super.effectiveFrom,
    super.createdAt,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: (json['id'] ?? json['_id'])?.toString(),
      userId: json['user_id'].toString(),
      calories: (json['calories'] as num).round(),
      proteinG: (json['protein_g'] as num).round(),
      fatG: (json['fat_g'] as num).round(),
      carbsG: ((json['carbs_g'] ?? 0) as num).round(),
      source: json['source'] == 'coach' ? GoalSource.coach : GoalSource.system,
      setBy: json['set_by']?.toString(),
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  factory GoalModel.fromEntity(NutritionalGoal g) => GoalModel(
    id: g.id,
    userId: g.userId,
    calories: g.calories,
    proteinG: g.proteinG,
    fatG: g.fatG,
    carbsG: g.carbsG,
    source: g.source,
    setBy: g.setBy,
    effectiveFrom: g.effectiveFrom,
    createdAt: g.createdAt,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'calories': calories,
    'protein_g': proteinG,
    'fat_g': fatG,
    'carbs_g': carbsG,
    'source': source == GoalSource.coach ? 'coach' : 'system',
    if (setBy != null) 'set_by': setBy,
    'effective_from': effectiveFrom.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
