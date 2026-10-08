import '../entities/nutritional_goal.dart';
import '../entities/user_profile.dart';

class CalculateNutritionalGoal {
  const CalculateNutritionalGoal();

  NutritionalGoal call(UserProfile p, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final age = p.ageAt(date);

    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * age;
    final bmr = p.gender == Gender.male ? base + 5 : base - 161;

    final tdee = bmr * _activityFactor(p.trainingDaysPerWeek);
    final calories = tdee * _objectiveAdjustment(p.objective);

    final proteinG = p.weightKg * _proteinPerKg(p.objective);
    final fatG = (calories * 0.25) / 9;

    final caloriesR = calories.round();
    final proteinR = proteinG.round();
    final fatR = fatG.round();
    final carbsR = ((caloriesR - proteinR * 4 - fatR * 9) / 4).round();

    return NutritionalGoal(
      userId: p.userId,
      calories: caloriesR,
      proteinG: proteinR,
      fatG: fatR,
      carbsG: carbsR < 0 ? 0 : carbsR,
      source: GoalSource.system,
      effectiveFrom: date,
    );
  }

  double _activityFactor(int days) {
    if (days <= 1) return 1.2;
    if (days <= 3) return 1.375;
    if (days <= 5) return 1.55;
    return 1.725;
  }

  double _objectiveAdjustment(FitnessObjective o) {
    switch (o) {
      case FitnessObjective.loseFat:
        return 0.80;
      case FitnessObjective.maintain:
        return 1.00;
      case FitnessObjective.gainMuscle:
        return 1.10;
    }
  }

  double _proteinPerKg(FitnessObjective o) {
    switch (o) {
      case FitnessObjective.loseFat:
        return 2.0;
      case FitnessObjective.maintain:
        return 1.6;
      case FitnessObjective.gainMuscle:
        return 1.8;
    }
  }
}
