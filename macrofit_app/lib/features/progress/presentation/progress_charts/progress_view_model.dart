import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../summary/domain/usecases/app_day.dart';
import '../../domain/entities/progress_period.dart';
import '../../domain/entities/progress_report.dart';
import '../../domain/repositories/progress_repository.dart';

/// HU-22 — progreso del usuario: gráficas de peso, macros y cumplimiento en una
/// semana o un mes (RF-18).
///
/// - Empieza en la semana que termina hoy (como el resumen semanal de HU-11).
/// - Cambiar entre semana y mes vuelve al periodo que incluye hoy.
/// - No se puede ir a un periodo futuro.
/// - Si falla una recarga se conserva el último reporte y se muestra el error.
class ProgressViewModel extends ViewModel {
  ProgressViewModel({
    required this._repository,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       _period = ProgressPeriod.current(ProgressRange.week, appDay(clock()));

  final ProgressRepository _repository;
  final DateTime Function() _clock;

  ProgressPeriod _period;
  ProgressReport? _report;
  bool _isLoading = false;
  String? _error;
  Macro _macro = Macro.calories;
  int _request = 0;

  ProgressPeriod get period => _period;
  ProgressRange get range => _period.range;

  /// Reporte del periodo actual; `null` mientras no ha cargado.
  ProgressReport? get report => _report;
  bool get isLoading => _isLoading;

  /// Mensaje del último error (p. ej. sin conexión); se puede reintentar.
  String? get error => _error;

  /// Macro que muestra la gráfica de consumo.
  Macro get macro => _macro;

  String get today => appDay(_clock());
  bool get canGoForward => _period.canGoForward(today);

  /// Consulta el periodo actual. Si la respuesta de un periodo anterior llega
  /// tarde, se descarta.
  Future<void> load() async {
    final request = ++_request;
    final period = _period;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final report = await _repository.getProgress(
        from: period.from,
        to: period.to,
      );
      if (request != _request) return;
      _report = report;
    } on ApiException catch (error) {
      if (request != _request) return;
      _error = error.message;
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Cambia entre semana y mes; vuelve al periodo que incluye hoy.
  Future<void> setRange(ProgressRange range) {
    if (range == _period.range) return Future.value();
    return _moveTo(ProgressPeriod.current(range, today));
  }

  Future<void> previous() => _moveTo(_period.previous());

  Future<void> next() =>
      canGoForward ? _moveTo(_period.next(today)) : Future.value();

  void selectMacro(Macro macro) {
    if (macro == _macro) return;
    _macro = macro;
    notifyListeners();
  }

  Future<void> _moveTo(ProgressPeriod period) {
    _period = period;
    // El reporte anterior es de otro periodo: no se muestra mientras carga.
    _report = null;
    return load();
  }
}
