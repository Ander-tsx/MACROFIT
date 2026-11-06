import '../../../../core/errors/api_exception.dart';
import '../../../goals/domain/entities/coach_client.dart';
import '../../../progress/domain/entities/progress_report.dart';
import '../../../progress/domain/repositories/progress_repository.dart';
// Excepción documentada a la regla de capas (README de `clients`): HU-23 reutiliza
// el estado de las gráficas de HU-22 en lugar de duplicarlo.
import '../../../progress/presentation/shared/progress_charts_view_model.dart';

/// HU-23 — progreso histórico de un cliente para su coach (RF-25). Solo lectura.
///
/// Las mismas gráficas y periodos que "Mi progreso" (HU-22), con
/// `GET /coach/clients/{clientId}/progress`. Si la API responde
/// `CLIENT_NOT_LINKED` el cliente ya no está vinculado (RN-04): [isUnlinked].
class ClientProgressViewModel extends ProgressChartsViewModel {
  ClientProgressViewModel({
    required this._repository,
    required this.client,
    super.clock,
  });

  final ProgressRepository _repository;
  final CoachClient client;

  bool _isUnlinked = false;

  /// La API respondió `CLIENT_NOT_LINKED`: el cliente ya no está vinculado (RN-04).
  bool get isUnlinked => _isUnlinked;

  @override
  Future<ProgressReport> fetch({required String from, required String to}) =>
      _repository.getClientProgress(clientId: client.id, from: from, to: to);

  @override
  bool handleError(ApiException error) {
    if (error.code != ApiErrorCode.clientNotLinked) return false;
    _isUnlinked = true;
    return true;
  }
}
