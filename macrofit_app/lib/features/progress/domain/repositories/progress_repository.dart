import '../entities/progress_report.dart';

/// HU-22 — series de progreso del usuario de la sesión.
abstract interface class ProgressRepository {
  /// Peso, macros por día y cumplimiento entre [from] y [to] (`YYYY-MM-DD`,
  /// ambos incluidos).
  Future<ProgressReport> getProgress({
    required String from,
    required String to,
  });
}
