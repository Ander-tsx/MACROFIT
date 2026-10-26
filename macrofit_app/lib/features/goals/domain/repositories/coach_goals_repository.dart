import '../entities/nutritional_goal.dart';

/// Metas de los clientes vinculados a un coach (HU-05).
/// La lista de clientes vive en la feature `clients` (HU-24).
/// Los métodos lanzan `ApiException` ante errores de la API o de red
/// (p. ej. `CLIENT_NOT_LINKED`, `VALIDATION_ERROR`).
abstract interface class CoachGoalsRepository {
  /// `GET /coach/clients/{clientId}/goals`, de la más reciente a la más antigua.
  Future<List<NutritionalGoal>> getClientGoals(String clientId);

  /// `POST /coach/clients/{clientId}/goals`. La meta anterior queda en el historial.
  Future<NutritionalGoal> setClientGoal(
    String clientId, {
    required int calories,
    required int proteinG,
    required int fatG,
    required DateTime effectiveFrom,
  });
}
