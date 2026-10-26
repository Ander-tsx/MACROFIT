import '../entities/client_summary.dart';

/// Clientes vinculados al coach de la sesión (HU-24).
/// Los métodos lanzan `ApiException` ante errores de la API o de red.
abstract interface class ClientsRepository {
  /// `GET /coach/clients`: solo vinculaciones activas, ordenadas por nombre.
  Future<List<ClientSummary>> getClients();
}
