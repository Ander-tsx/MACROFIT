import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/my_routines/presentation/routine_detail/routine_detail_view_model.dart';
import 'package:macrofit_app/features/my_routines/presentation/widgets/my_routine_texts.dart';

import '../../../helpers/fakes.dart';

/// 12:00 en México del 7 de noviembre (18:00 UTC): el «hoy» del fake.
DateTime noon() => DateTime.utc(2026, 11, 7, 18);

RoutineDetailViewModel build(FakeMyRoutinesRepository repository) =>
    RoutineDetailViewModel(
      repository: repository,
      routineId: 'rec1',
      now: noon,
    );

Future<bool> yes() async => true;
Future<bool> no() async => false;

void main() {
  late FakeMyRoutinesRepository repository;

  setUp(() {
    repository = FakeMyRoutinesRepository(routines: [testRecommendedRoutine()]);
  });

  test('al abrir el detalle marca las sesiones completadas hoy, no las de otros días', () async {
    repository.completed['rec1'] = [
      testCompletedSession(number: 2),
      testCompletedSession(number: 1, date: '2026-11-06'),
    ];
    final viewModel = build(repository);

    await viewModel.load();

    expect(viewModel.today, '2026-11-07');
    expect(viewModel.completedToday(2)?.date, '2026-11-07');
    expect(viewModel.completedToday(1), isNull, reason: 'fue ayer');
    expect(viewModel.completedToday(3), isNull);
  });

  test(
    'marcar con confirmación envía el número de la sesión y la deja marcada',
    () async {
      final viewModel = build(repository);
      await viewModel.load();

      final result = await viewModel.complete(3, yes);

      expect(result, CompleteSessionResult.completed);
      expect(repository.completeRequests, [('rec1', 3)]);
      expect(viewModel.completedToday(3), isNotNull);
      expect(viewModel.isCompletingAny, isFalse);
    },
  );

  test('cancelar la confirmación no registra nada', () async {
    final viewModel = build(repository);
    await viewModel.load();

    final result = await viewModel.complete(1, no);

    expect(result, CompleteSessionResult.cancelled);
    expect(repository.completeRequests, isEmpty);
  });

  test('una sesión ya marcada hoy no se puede registrar dos veces', () async {
    repository.completed['rec1'] = [testCompletedSession(number: 1)];
    final viewModel = build(repository);
    await viewModel.load();

    final result = await viewModel.complete(1, yes);

    expect(result, CompleteSessionResult.cancelled);
    expect(repository.completeRequests, isEmpty);
  });

  test(
    'si ya se registró hoy en otro dispositivo, lo indica y la marca',
    () async {
      final viewModel = build(repository);
      await viewModel.load();
      repository.completedElsewhere = true;

      final result = await viewModel.complete(2, yes);

      expect(result, CompleteSessionResult.alreadyCompleted);
      expect(viewModel.completedToday(2), isNotNull);
      expect(viewModel.completeError, isNull);
    },
  );

  test(
    'una rutina retirada queda no disponible para regresar a la lista',
    () async {
      final viewModel = build(repository);
      await viewModel.load();
      repository.routines = [];

      final result = await viewModel.complete(1, yes);

      expect(result, CompleteSessionResult.unavailable);
      expect(viewModel.isUnavailable, isTrue);
      expect(viewModel.takeUnavailable(), isTrue);
    },
  );

  test(
    'sin conexión no se pierde en silencio: muestra el error y se reintenta',
    () async {
      final viewModel = build(repository);
      await viewModel.load();
      repository.completeError = networkError;

      final failed = await viewModel.complete(1, yes);

      expect(failed, CompleteSessionResult.failed);
      expect(viewModel.completeError, 'Sin conexión');
      expect(viewModel.lastFailedNumber, 1);
      expect(viewModel.completedToday(1), isNull);

      repository.completeError = null;
      final retried = await viewModel.complete(1, yes);

      expect(retried, CompleteSessionResult.completed);
      expect(viewModel.completeError, isNull);
      expect(viewModel.lastFailedNumber, isNull);
      expect(viewModel.completedToday(1), isNotNull);
    },
  );

  test(
    'si fallan las sesiones completadas, la rutina se muestra igual',
    () async {
      repository.sessionsError = networkError;
      final viewModel = build(repository);

      await viewModel.load();

      expect(viewModel.routine, isNotNull);
      expect(viewModel.error, isNull);
      expect(viewModel.sessionsError, 'Sin conexión');
    },
  );

  test('ApiErrorCode conoce SESSION_ALREADY_COMPLETED', () {
    expect(ApiErrorCode.sessionAlreadyCompleted, 'SESSION_ALREADY_COMPLETED');
  });

  test('texto de la sesión completada con su fecha', () {
    expect(completedTodayText('2026-11-07'), 'Completada hoy · 7 de noviembre');
  });
}
