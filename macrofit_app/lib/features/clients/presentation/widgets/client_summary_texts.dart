import '../../../goals/domain/entities/nutritional_goal.dart';
import '../../domain/entities/client_summary.dart';

/// `2200 kcal · P 160 g · G 70 g`, o `Sin meta` si el cliente no tiene metas.
String goalSummaryText(ClientGoalSummary? goal) => goal == null
    ? 'Sin meta'
    : '${goal.calories} kcal · P ${goal.proteinG} g · G ${goal.fatG} g';

/// Origen de la meta: `Meta del coach` o `Meta calculada`.
String goalSourceText(ClientGoalSummary goal) => switch (goal.source) {
  GoalSource.coach => 'Meta del coach',
  GoalSource.system => 'Meta calculada',
};

/// `Último registro: hoy, 14:30`, `ayer, 09:05`, `17/10/2026` o `Sin registros`.
/// La fecha se muestra en la hora local del teléfono.
String lastMealText(DateTime? lastMealAt, {required DateTime now}) {
  if (lastMealAt == null) return 'Sin registros';
  final local = lastMealAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final when = switch (today.difference(day).inDays) {
    0 => 'hoy, $time',
    1 => 'ayer, $time',
    _ => '${two(local.day)}/${two(local.month)}/${local.year}',
  };
  return 'Último registro: $when';
}
