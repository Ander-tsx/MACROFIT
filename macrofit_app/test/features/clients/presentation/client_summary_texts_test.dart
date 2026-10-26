import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/clients/presentation/widgets/client_summary_texts.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';

void main() {
  const coachGoal = ClientGoalSummary(
    calories: 2200,
    proteinG: 160,
    fatG: 70,
    source: GoalSource.coach,
  );

  test('resume la meta con calorías, proteína y grasa', () {
    expect(goalSummaryText(coachGoal), '2200 kcal · P 160 g · G 70 g');
  });

  test('indica el origen de la meta', () {
    expect(goalSourceText(coachGoal), 'Meta del coach');
    expect(
      goalSourceText(
        const ClientGoalSummary(
          calories: 1900,
          proteinG: 140,
          fatG: 53,
          source: GoalSource.system,
        ),
      ),
      'Meta calculada',
    );
  });

  test('sin meta lo indica', () {
    expect(goalSummaryText(null), 'Sin meta');
  });

  test('el último registro de hoy o de ayer muestra la hora local', () {
    final now = DateTime(2026, 10, 25, 20);
    expect(
      lastMealText(DateTime(2026, 10, 25, 14, 30), now: now),
      'Último registro: hoy, 14:30',
    );
    expect(
      lastMealText(DateTime(2026, 10, 24, 9, 5), now: now),
      'Último registro: ayer, 09:05',
    );
    expect(
      lastMealText(DateTime(2026, 10, 17, 1, 30), now: now),
      'Último registro: 17/10/2026',
    );
  });

  test('sin registros lo indica', () {
    expect(lastMealText(null, now: DateTime(2026, 10, 25)), 'Sin registros');
  });
}
