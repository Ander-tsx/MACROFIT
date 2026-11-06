import '../entities/progress_report.dart';

/// HU-22 / HU-23 — series de progreso. Los métodos lanzan `ApiException` ante
/// errores de la API o de red (p. ej. `CLIENT_NOT_LINKED`).
abstract interface class ProgressRepository {
  /// HU-22 — progreso del usuario de la sesión: peso, macros por día y
  /// cumplimiento entre [from] y [to] (`YYYY-MM-DD`, ambos incluidos).
  Future<ProgressReport> getProgress({
    required String from,
    required String to,
  });

  /// HU-23 — el mismo progreso de un cliente vinculado al coach de la sesión
  /// (`403 CLIENT_NOT_LINKED` si ya no lo está, RN-04).
  Future<ProgressReport> getClientProgress({
    required String clientId,
    required String from,
    required String to,
  });
}
