import '../entities/nutritional_goal.dart';

abstract class GoalsRepository {
  Future<NutritionalGoal> getCurrentGoal();
  Future<List<NutritionalGoal>> getGoalsHistory();
}
