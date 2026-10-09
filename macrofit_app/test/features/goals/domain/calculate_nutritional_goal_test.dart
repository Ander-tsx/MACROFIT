import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/goals/domain/entities/user_profile.dart';
import 'package:macrofit_app/features/goals/domain/usecases/calculate_nutritional_goal.dart';

void main() {
  const calculate = CalculateNutritionalGoal();

  // Fecha fija para que la edad no dependa del día en que se corran las pruebas.
  final now = DateTime(2026, 1, 1);

  UserProfile profile({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
    required int days,
    required FitnessObjective objective,
  }) {
    return UserProfile(
      userId: 'user-1',
      weightKg: weightKg,
      heightCm: heightCm,
      birthDate: DateTime(now.year - age, 1, 1),
      gender: gender,
      trainingDaysPerWeek: days,
      objective: objective,
    );
  }

  group('CalculateNutritionalGoal (Mifflin-St Jeor)', () {
    test('hombre bajar grasa coincide con el cálculo manual', () {
      // TMB = 10·80 + 6.25·180 − 5·25 + 5 = 1805
      // × 1.55 (4 días) = 2797.75; × 0.80 = 2238.2 kcal
      // Proteína = 80 × 2.0 = 160 g; Grasa = 2238.2 × 0.25 / 9 ≈ 62.17 g
      final goal = calculate(
        profile(
          weightKg: 80,
          heightCm: 180,
          age: 25,
          gender: Gender.male,
          days: 4,
          objective: FitnessObjective.loseFat,
        ),
        now: now,
      );

      expect(goal.calories, closeTo(2238.2, 1));
      expect(goal.proteinG, closeTo(160, 1));
      expect(goal.fatG, closeTo(62.17, 1));
    });

    test('mujer ganar músculo coincide con el cálculo manual', () {
      // TMB = 10·60 + 6.25·165 − 5·22 − 161 = 1360.25
      // × 1.55 (5 días) = 2108.39; × 1.10 = 2319.23 kcal
      // Proteína = 60 × 1.8 = 108 g; Grasa = 2319.23 × 0.25 / 9 ≈ 64.42 g
      final goal = calculate(
        profile(
          weightKg: 60,
          heightCm: 165,
          age: 22,
          gender: Gender.female,
          days: 5,
          objective: FitnessObjective.gainMuscle,
        ),
        now: now,
      );

      expect(goal.calories, closeTo(2319.23, 1));
      expect(goal.proteinG, closeTo(108, 1));
      expect(goal.fatG, closeTo(64.42, 1));
    });

    test('hombre mantener coincide con el cálculo manual', () {
      // TMB = 10·70 + 6.25·175 − 5·30 + 5 = 1648.75
      // × 1.375 (3 días) = 2267.03 kcal (ajuste 0 %)
      // Proteína = 70 × 1.6 = 112 g; Grasa = 2267.03 × 0.25 / 9 ≈ 62.97 g
      final goal = calculate(
        profile(
          weightKg: 70,
          heightCm: 175,
          age: 30,
          gender: Gender.male,
          days: 3,
          objective: FitnessObjective.maintain,
        ),
        now: now,
      );

      expect(goal.calories, closeTo(2267.03, 1));
      expect(goal.proteinG, closeTo(112, 1));
      expect(goal.fatG, closeTo(62.97, 1));
    });

    test('los resultados salen redondeados a enteros', () {
      final goal = calculate(
        profile(
          weightKg: 80,
          heightCm: 180,
          age: 25,
          gender: Gender.male,
          days: 4,
          objective: FitnessObjective.loseFat,
        ),
        now: now,
      );

      expect(goal.calories, 2238);
      expect(goal.proteinG, 160);
      expect(goal.fatG, 62);
    });

    test('el factor de actividad cambia en los límites de cada rango', () {
      // Hombre 80 kg, 180 cm, 25 años, mantener: TMB = 1805
      const expectedByDays = {
        1: 2166, // × 1.2
        2: 2482, // × 1.375
        3: 2482,
        4: 2798, // × 1.55
        5: 2798,
        6: 3114, // × 1.725
        7: 3114,
      };

      expectedByDays.forEach((days, expectedCalories) {
        final goal = calculate(
          profile(
            weightKg: 80,
            heightCm: 180,
            age: 25,
            gender: Gender.male,
            days: days,
            objective: FitnessObjective.maintain,
          ),
          now: now,
        );
        expect(goal.calories, expectedCalories, reason: '$days días');
      });
    });

    test(
      'la meta calculada es del sistema, del usuario y vigente desde ahora',
      () {
        final goal = calculate(
          profile(
            weightKg: 70,
            heightCm: 175,
            age: 30,
            gender: Gender.male,
            days: 3,
            objective: FitnessObjective.maintain,
          ),
          now: now,
        );

        expect(goal.source, GoalSource.system);
        expect(goal.setBy, isNull);
        expect(goal.userId, 'user-1');
        expect(goal.effectiveFrom, now);
      },
    );
  });
}
