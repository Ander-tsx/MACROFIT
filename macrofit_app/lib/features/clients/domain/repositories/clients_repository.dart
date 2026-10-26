import 'dart:typed_data';

import '../entities/client_meal.dart';
import '../entities/client_summary.dart';

/// Clientes vinculados al coach de la sesión (HU-24) y sus comidas (HU-25).
/// Los métodos lanzan `ApiException` ante errores de la API o de red
/// (p. ej. `CLIENT_NOT_LINKED`).
abstract interface class ClientsRepository {
  /// `GET /coach/clients`: solo vinculaciones activas, ordenadas por nombre.
  Future<List<ClientSummary>> getClients();

  /// `GET /coach/clients/{clientId}/meals?date=`: registros de ese día, del más
  /// antiguo al más reciente. Solo se consideran año, mes y día de [date].
  Future<List<ClientMeal>> getClientMeals(String clientId, DateTime date);

  /// Descarga la foto de un registro desde su `photo_url` con la sesión del coach.
  Future<Uint8List> getMealPhoto(String photoUrl);
}
