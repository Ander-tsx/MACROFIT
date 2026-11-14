import 'package:flutter/foundation.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../summary/domain/usecases/app_day.dart';
import '../../domain/entities/progress_period.dart';
import '../../domain/entities/progress_report.dart';

/// Estado común de las gráficas de progreso por semana o por mes: HU-22 (el
/// usuario, `ProgressViewModel`) y HU-23 (el coach, `ClientProgressViewModel`).
/// Cada pantalla solo decide de dónde sale el reporte ([fetch]) y qué errores
/// trata de forma especial ([handleError]).
///
/// - Empieza en la semana que termina hoy (como el resumen semanal de HU-11).
/// - Cambiar entre semana y mes vuelve al periodo que incluye hoy.
/// - No se puede ir a un periodo futuro.
/// - Si falla una recarga se conserva el último reporte y se muestra el error.
/// - La respuesta de un periodo que ya no se ve se descarta.
abstract class ProgressChartsViewModel extends ViewModel {
  ProgressChartsViewModel({DateTime Function() clock = DateTime.now})
    : _clock = clock,
      _period = ProgressPeriod.current(ProgressRange.week, appDay(clock()));

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

  /// Pide el reporte de [from] a [to] (`YYYY-MM-DD`).
  @protected
  Future<ProgressReport> fetch({required String from, required String to});

  /// Trata un error de forma especial; `true` si ya no hay que mostrar [error].
  @protected
  bool handleError(ApiException error) => false;

  /// Consulta el periodo actual. Si la respuesta de un periodo anterior llega
  /// tarde, se descarta.
  Future<void> load() async {
    final request = ++_request;
    final period = _period;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final report = await fetch(from: period.from, to: period.to);
      if (request != _request) return;
      _report = report;
    } on ApiException catch (error) {
      if (request != _request) return;
      if (!handleError(error)) _error = error.message;
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
