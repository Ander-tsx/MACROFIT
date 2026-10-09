import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/goals/domain/entities/user_profile.dart';
import 'package:macrofit_app/features/goals/domain/usecases/update_goal_on_profile_change.dart';

void main() {
  const updateGoal = UpdateGoalOnProfileChange();

  final now = DateTime(2026, 1, 1);

  UserProfile profile({double weightKg = 80}) {
    return UserProfile(
      userId: 'user-1',
      weightKg: weightKg,
      heightCm: 180,
      birthDate: DateTime(2001, 1, 1),
      gender: Gender.male,
      trainingDaysPerWeek: 4,
      objective: FitnessObjective.maintain,
    );
  }

  NutritionalGoal goal({
    required GoalSource source,
    int calories = 2800,
    String? setBy,
  }) {
    return NutritionalGoal(
      userId: 'user-1',
      calories: calories,
      proteinG: 130,
      fatG: 78,
      carbsG: 380,
      source: source,
      setBy: setBy,
      effectiveFrom: DateTime(2025, 12, 1),
      createdAt: DateTime(2025, 12, 1),
    );
  }

  group('UpdateGoalOnProfileChange', () {
    test('si la meta vigente es de un coach no se reemplaza', () {
      final coachGoal = goal(source: GoalSource.coach, setBy: 'coach-1');

      final result = updateGoal(
        currentGoal: coachGoal,
        updatedProfile: profile(weightKg: 90),
        now: now,
      );

      expect(result, isNull);
    });

    test('si la meta vigente es del sistema genera una meta nueva', () {
      final systemGoal = goal(source: GoalSource.system);

      final result = updateGoal(
        currentGoal: systemGoal,
        updatedProfile: profile(weightKg: 90),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.source, GoalSource.system);
      expect(result.userId, 'user-1');
      expect(result.effectiveFrom, now);
      expect(result.calories, isNot(systemGoal.calories));
    });

    test('la meta nueva usa los datos del perfil editado', () {
      final result = updateGoal(
        currentGoal: goal(source: GoalSource.system),
        updatedProfile: profile(weightKg: 80),
        now: now,
      );

      // Hombre 80 kg, 180 cm, 25 años, 4 días, mantener:
      // TMB 1805 × 1.55 = 2797.75 → 2798 kcal; proteína 80 × 1.6 = 128 g
      expect(result!.calories, 2798);
      expect(result.proteinG, 128);
    });

    test('sin meta previa genera la meta inicial del sistema', () {
      final result = updateGoal(
        currentGoal: null,
        updatedProfile: profile(),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.source, GoalSource.system);
    });

    test('la meta previa se conserva en el historial al agregar la nueva', () {
      final previous = goal(source: GoalSource.system);
      final history = <NutritionalGoal>[previous];

      final newGoal = updateGoal(
        currentGoal: previous,
        updatedProfile: profile(weightKg: 90),
        now: now,
      );
      if (newGoal != null) history.add(newGoal);

      expect(history, hasLength(2));
      expect(history.first, same(previous));
      expect(history.first.calories, 2800); // la anterior no se modificó
      expect(history.last.calories, isNot(2800));
    });

    test('con una meta de coach el historial no cambia', () {
      final coachGoal = goal(source: GoalSource.coach, setBy: 'coach-1');
      final history = <NutritionalGoal>[coachGoal];

      final newGoal = updateGoal(
        currentGoal: coachGoal,
        updatedProfile: profile(weightKg: 90),
        now: now,
      );
      if (newGoal != null) history.add(newGoal);

      expect(history, hasLength(1));
      expect(history.single, same(coachGoal));
    });
  });
}
