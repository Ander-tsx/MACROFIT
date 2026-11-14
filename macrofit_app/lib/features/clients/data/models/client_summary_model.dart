import '../../../goals/domain/entities/nutritional_goal.dart';
import '../../domain/entities/client_summary.dart';

/// Un elemento de `GET /coach/clients` (HU-24).
class ClientSummaryModel extends ClientSummary {
  const ClientSummaryModel({
    required super.id,
    required super.name,
    required super.email,
    super.goal,
    super.lastMealAt,
  });

  factory ClientSummaryModel.fromJson(Map<String, dynamic> json) {
    final goal = json['goal'] as Map<String, dynamic>?;
    final lastMealAt = json['last_meal_at'] as String?;
    return ClientSummaryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      goal: goal == null
          ? null
          : ClientGoalSummary(
              calories: (goal['calories'] as num).round(),
              proteinG: (goal['protein_g'] as num).round(),
              fatG: (goal['fat_g'] as num).round(),
              source: goal['source'] == 'coach'
                  ? GoalSource.coach
                  : GoalSource.system,
            ),
      lastMealAt: lastMealAt == null ? null : DateTime.parse(lastMealAt),
    );
  }
}
