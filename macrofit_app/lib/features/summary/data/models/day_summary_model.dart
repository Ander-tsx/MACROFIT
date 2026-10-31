import '../../../goals/domain/entities/nutritional_goal.dart';
import '../../domain/entities/day_summary.dart';
import '../../domain/entities/macro_values.dart';

class DaySummaryModel extends DaySummary {
  const DaySummaryModel({
    required super.date,
    required super.goalSource,
    required super.goal,
    required super.consumed,
    required super.remaining,
  });

  factory DaySummaryModel.fromJson(Map<String, dynamic> json) {
    final goal = json['goal'] as Map<String, dynamic>;
    return DaySummaryModel(
      date: json['date'] as String,
      goalSource: goal['source'] == 'coach'
          ? GoalSource.coach
          : GoalSource.system,
      goal: macroValuesFromJson(goal),
      consumed: macroValuesFromJson(json['consumed'] as Map<String, dynamic>),
      remaining: macroValuesFromJson(json['remaining'] as Map<String, dynamic>),
    );
  }
}

MacroValues macroValuesFromJson(Map<String, dynamic> json) => MacroValues(
  caloriesKcal: (json['calories_kcal'] as num).toDouble(),
  proteinG: (json['protein_g'] as num).toDouble(),
  fatG: (json['fat_g'] as num).toDouble(),
);
