enum GoalSource { system, coach }

class NutritionalGoal {
  final String? id;
  final String userId;
  final int calories;
  final int proteinG;
  final int fatG;
  final int carbsG;
  final GoalSource source;
  final String? setBy;
  final DateTime effectiveFrom;
  final DateTime? createdAt;

  const NutritionalGoal({
    this.id,
    required this.userId,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.source,
    this.setBy,
    required this.effectiveFrom,
    this.createdAt,
  });
}
