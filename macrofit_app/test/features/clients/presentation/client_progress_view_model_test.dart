import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/core/presentation/theme/macro_style.dart';
import 'package:macrofit_app/features/clients/presentation/client_progress/client_progress_view_model.dart';
import 'package:macrofit_app/features/progress/domain/entities/progress_period.dart';

import '../../../helpers/fakes.dart';

void main() {
  // 5 de noviembre de 2026 a mediodía en México (UTC-6).
  DateTime clock() => DateTime.utc(2026, 11, 5, 18);

  late FakeProgressRepository repository;
  late ClientProgressViewModel viewModel;

  setUp(() {
    repository = FakeProgressRepository();
    viewModel = ClientProgressViewModel(
      repository: repository,
      client: testClientSummary,
      clock: clock,
    );
  });

  test('carga la semana que termina hoy del cliente elegido', () async {
    expect(viewModel.range, ProgressRange.week);

    await viewModel.load();

    expect(repository.clientRequests, [testClientSummary.id]);
    expect(repository.requests, ['2026-10-30..2026-11-05']);
    final report = viewModel.report!;
    expect(report.days, hasLength(7));
    expect(report.hasWeightTrend, isTrue);
    expect(report.hasMeals, isTrue);
    expect(report.hasCompliance, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.error, isNull);
    expect(viewModel.isUnlinked, isFalse);
    expect(viewModel.canGoForward, isFalse);
  });

  test('un periodo sin datos no tiene gráficas y no es un error', () async {
    repository.withData = false;

    await viewModel.load();

    final report = viewModel.report!;
    expect(report.hasWeightTrend, isFalse);
    expect(report.hasMeals, isFalse);
    expect(viewModel.error, isNull);
    expect(viewModel.isUnlinked, isFalse);
  });

  test('cambia a mes (del día 1 a hoy) y vuelve a semana', () async {
    await viewModel.load();

    await viewModel.setRange(ProgressRange.month);
    expect(viewModel.range, ProgressRange.month);
    expect(repository.requests.last, '2026-11-01..2026-11-05');
    expect(viewModel.report?.days, hasLength(5));

    await viewModel.setRange(ProgressRange.week);
    expect(repository.requests.last, '2026-10-30..2026-11-05');
    expect(repository.clientRequests.toSet(), {testClientSummary.id});
  });

  test('elegir el mismo periodo no vuelve a pedirlo', () async {
    await viewModel.load();
    await viewModel.setRange(ProgressRange.week);

    expect(repository.requests, hasLength(1));
  });

  test('navega a periodos anteriores y no pasa de hoy', () async {
    await viewModel.setRange(ProgressRange.month);
    await viewModel.previous();
    expect(repository.requests.last, '2026-10-01..2026-10-31');
    expect(viewModel.canGoForward, isTrue);

    await viewModel.next();
    expect(repository.requests.last, '2026-11-01..2026-11-05');

    final requests = repository.requests.length;
    await viewModel.next();
    expect(repository.requests, hasLength(requests));
  });

  test(
    'CLIENT_NOT_LINKED marca al cliente como desvinculado (RN-04)',
    () async {
      repository.error = apiError(ApiErrorCode.clientNotLinked, status: 403);

      await viewModel.load();

      expect(viewModel.isUnlinked, isTrue);
      // No se muestra como error de red con reintento.
      expect(viewModel.error, isNull);
      expect(viewModel.report, isNull);
      expect(viewModel.isLoading, isFalse);
    },
  );

  test('sin conexión muestra el mensaje y al reintentar carga', () async {
    repository.error = networkError;

    await viewModel.load();

    expect(viewModel.error, networkError.message);
    expect(viewModel.isUnlinked, isFalse);
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
    viewModel.selectMacro(Macro.fat);

    expect(viewModel.macro, Macro.fat);
  });
}
