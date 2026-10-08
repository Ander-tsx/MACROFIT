import '../entities/nutritional_goal.dart';
import '../entities/user_profile.dart';
import 'calculate_nutritional_goal.dart';

class UpdateGoalOnProfileChange {
  final CalculateNutritionalGoal _calculate;

  const UpdateGoalOnProfileChange(
      [this._calculate = const CalculateNutritionalGoal()]);

  /// Devuelve la nueva meta a insertar en el historial,
  /// o `null` si la meta vigente es de un coach (no se reemplaza).
  /// La meta previa nunca se modifica: solo se agrega un registro nuevo.
  NutritionalGoal? call({
    required NutritionalGoal? currentGoal,
    required UserProfile updatedProfile,
    DateTime? now,
  }) {
    if (currentGoal?.source == GoalSource.coach) return null;
    return _calculate(updatedProfile, now: now);
  }
}
