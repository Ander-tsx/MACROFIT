import '../entities/coach_client.dart';
import '../entities/nutritional_goal.dart';

/// Metas de los clientes vinculados a un coach (HU-05).
/// Los métodos lanzan `ApiException` ante errores de la API o de red
/// (p. ej. `CLIENT_NOT_LINKED`, `VALIDATION_ERROR`).
abstract interface class CoachGoalsRepository {
  /// `GET /coach/clients`.
  // TODO(HU-24): la lista de clientes completa reemplaza a esta mínima.
  Future<List<CoachClient>> getClients();

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
