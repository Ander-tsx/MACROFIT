import '../../../goals/domain/entities/coach_client.dart';
import '../../../goals/domain/entities/nutritional_goal.dart';

/// Meta vigente de un cliente, resumida para la lista del coach (HU-24).
class ClientGoalSummary {
  const ClientGoalSummary({
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.source,
  });

  final int calories;
  final int proteinG;
  final int fatG;
  final GoalSource source;

  @override
  bool operator ==(Object other) =>
      other is ClientGoalSummary &&
      other.calories == calories &&
      other.proteinG == proteinG &&
      other.fatG == fatG &&
      other.source == source;

  @override
  int get hashCode => Object.hash(calories, proteinG, fatG, source);
}

/// Cliente vinculado con su meta vigente y su último registro de comida (HU-24).
///
/// Es un [CoachClient], así que abre directamente la pantalla de metas de HU-05.
class ClientSummary extends CoachClient {
  const ClientSummary({
    required super.id,
    required super.name,
    required super.email,
    this.goal,
    this.lastMealAt,
  });

  /// `null` si el cliente aún no tiene metas.
  final ClientGoalSummary? goal;

  /// Fecha y hora del registro de comida más reciente; `null` si no tiene registros.
  final DateTime? lastMealAt;
}
