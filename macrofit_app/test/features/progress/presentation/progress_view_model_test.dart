import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/presentation/theme/macro_style.dart';
import 'package:macrofit_app/features/progress/domain/entities/progress_period.dart';
import 'package:macrofit_app/features/progress/presentation/progress_charts/progress_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  // 5 de noviembre de 2026 a mediodía en México (UTC-6).
  DateTime clock() => DateTime.utc(2026, 11, 5, 18);

  late FakeProgressRepository repository;
  late ProgressViewModel viewModel;

  setUp(() {
    repository = FakeProgressRepository();
    viewModel = ProgressViewModel(repository: repository, clock: clock);
  });

  test('empieza en la semana que termina hoy y la carga', () async {
    expect(viewModel.range, ProgressRange.week);
    await viewModel.load();

    expect(repository.requests, ['2026-10-30..2026-11-05']);
    expect(viewModel.report?.days, hasLength(7));
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.canGoForward, isFalse);
  });

  test('cambia a mes: del día 1 hasta hoy', () async {
    await viewModel.setRange(ProgressRange.month);

    expect(repository.requests.last, '2026-11-01..2026-11-05');
    expect(viewModel.period.range, ProgressRange.month);
    expect(viewModel.report?.days, hasLength(5));
  });

  test('va al periodo anterior y regresa, sin pasar de hoy', () async {
    await viewModel.load();
    await viewModel.previous();
    expect(repository.requests.last, '2026-10-23..2026-10-29');
    expect(viewModel.canGoForward, isTrue);

    await viewModel.next();
    expect(repository.requests.last, '2026-10-30..2026-11-05');

    final requests = repository.requests.length;
    await viewModel.next();
    expect(repository.requests, hasLength(requests));
  });

  test('en mes, el anterior es octubre completo', () async {
    await viewModel.setRange(ProgressRange.month);
    await viewModel.previous();
    expect(repository.requests.last, '2026-10-01..2026-10-31');
    expect(viewModel.report?.days, hasLength(31));
  });

  test('un periodo sin datos no tiene gráficas que mostrar', () async {
    repository.withData = false;
    await viewModel.load();

    final report = viewModel.report!;
    expect(report.hasWeightTrend, isFalse);
    expect(report.hasMeals, isFalse);
    expect(viewModel.error, isNull);
  });

  test('sin conexión guarda el mensaje y al reintentar lo limpia', () async {
    repository.error = networkError;
    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.report, isNull);

    repository.error = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.report, isNotNull);
  });

  test('si falla una recarga conserva el último reporte', () async {
    await viewModel.load();
    repository.error = networkError;
    await viewModel.load();

    expect(viewModel.report, isNotNull);
    expect(viewModel.error, networkError.message);
  });

  test('descarta la respuesta de un periodo que ya no se ve', () async {
    final gate = repository.gate = Completer<void>();
    final first = viewModel.load();
    repository.gate = null;
    await viewModel.previous();
    gate.complete();
    await first;

    expect(viewModel.period.from, '2026-10-23');
    expect(viewModel.report?.from, '2026-10-23');
  });

  test('elige el macro de la gráfica de consumo', () {
    var notified = 0;
    viewModel.addListener(() => notified++);

    viewModel.selectMacro(Macro.protein);
    viewModel.selectMacro(Macro.protein);

    expect(viewModel.macro, Macro.protein);
    expect(notified, 1);
  });
}
