import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/week_summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../../domain/usecases/app_day.dart';

/// HU-11 — resumen semanal: 7 días contra la meta de cada día, promedio y días con la
/// meta cumplida. La semana inicial termina hoy; se puede ir a las anteriores y volver.
class WeeklySummaryViewModel extends ViewModel {
  WeeklySummaryViewModel({
    required this._repository,
    this._clock = DateTime.now,
  }) {
    _start = shiftDay(today, -6);
  }

  final SummaryRepository _repository;
  final DateTime Function() _clock;

  late String _start;
  WeekSummary? _summary;
  bool _isLoading = false;
  bool _hasNoSummary = false;
  String? _error;

  /// Para descartar la respuesta de una semana que ya no es la que se ve.
  int _request = 0;

  /// Hoy (`YYYY-MM-DD`, hora de México).
  String get today => appDay(_clock());

  /// Primer y último día de la semana que se ve.
  String get start => _start;
  String get end => shiftDay(_start, 6);

  WeekSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  /// `404 PROFILE_NOT_FOUND`: sin perfil ni meta no hay con qué comparar.
  bool get hasNoSummary => _hasNoSummary;

  /// Error al consultar (p. ej. sin conexión); se puede reintentar.
  String? get error => _error;

  /// La semana siguiente no puede terminar después de hoy.
  bool get canGoForward => shiftDay(end, 7).compareTo(today) <= 0;

  Future<void> previousWeek() => _moveTo(shiftDay(_start, -7));

  Future<void> nextWeek() async {
    if (!canGoForward) return;
    await _moveTo(shiftDay(_start, 7));
  }

  Future<void> _moveTo(String start) {
    _start = start;
    // Lo que se ve es de otra semana: se quita para no mostrarlo bajo otras fechas.
    _summary = null;
    _hasNoSummary = false;
    _error = null;
    return load(force: true);
  }

  /// Consulta (o vuelve a consultar) la semana que se ve. Si falla una recarga de la
  /// misma semana, conserva el último resumen.
  Future<void> load({bool force = false}) async {
    if (_isLoading && !force) return;
    final request = ++_request;
    final start = _start;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final summary = await _repository.getWeekly(start);
      if (request != _request) return;
      _summary = summary;
      _hasNoSummary = false;
    } on ApiException catch (error) {
      if (request != _request) return;
      if (error.code == ApiErrorCode.profileNotFound) {
        _summary = null;
        _hasNoSummary = true;
      } else {
        _error = error.message;
      }
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
