import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/routines/presentation/routines_list/routines_list_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeRoutinesRepository repository;
  late RoutinesListViewModel viewModel;

  setUp(() {
    repository = FakeRoutinesRepository();
    viewModel = RoutinesListViewModel(repository);
  });

  tearDown(() => viewModel.dispose());

  Future<bool> yes() async => true;
  Future<bool> no() async => false;

  test('carga las rutinas del coach en el orden de la API', () async {
    await viewModel.load();

    expect(viewModel.routines, [testRoutine, testLegRoutine]);
    expect(viewModel.hasNoRoutines, isFalse);
    expect(viewModel.error, isNull);
  });

  test('sin rutinas lo indica (no es un error)', () async {
    repository.routines = [];
    expect(viewModel.hasNoRoutines, isFalse, reason: 'aún no se consulta');

    await viewModel.load();

    expect(viewModel.hasNoRoutines, isTrue);
    expect(viewModel.error, isNull);
  });

  test('sin red muestra el error y reintentar vuelve a consultar', () async {
    repository.listError = networkError;
    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.hasNoRoutines, isFalse);

    repository.listError = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.routines, hasLength(2));
    expect(repository.listCalls, 2);
  });

  test('si falla una recarga conserva la última lista', () async {
    await viewModel.load();
    repository.listError = networkError;

    await viewModel.load();

    expect(viewModel.routines, [testRoutine, testLegRoutine]);
    expect(viewModel.error, networkError.message);
  });

  group('eliminar', () {
    test('confirmado: llama a la API y recarga la lista', () async {
      await viewModel.load();

      final deleted = await viewModel.delete(testRoutine, yes);

      expect(deleted, isTrue);
      expect(repository.deleted, [testRoutine.id]);
      expect(viewModel.routines, [testLegRoutine]);
      expect(repository.listCalls, 2);
      expect(viewModel.isDeleting, isFalse);
    });

    test('cancelado: no llama a la API', () async {
      await viewModel.load();

      final deleted = await viewModel.delete(testRoutine, no);

      expect(deleted, isFalse);
      expect(repository.deleted, isEmpty);
      expect(viewModel.routines, hasLength(2));
    });

    test('con error conserva la rutina y muestra el mensaje', () async {
      await viewModel.load();
      repository.deleteError = networkError;

      final deleted = await viewModel.delete(testRoutine, yes);

      expect(deleted, isFalse);
      expect(viewModel.routines, [testRoutine, testLegRoutine]);
      expect(viewModel.error, networkError.message);
      expect(viewModel.isDeleting, isFalse);
    });

    test('si ya no existe (404) la quita de la lista', () async {
      await viewModel.load();
      repository
        ..deleteError = apiError(ApiErrorCode.routineNotFound, status: 404)
        ..routines = [testLegRoutine];

      final deleted = await viewModel.delete(testRoutine, yes);

      expect(deleted, isTrue);
      expect(viewModel.routines, [testLegRoutine]);
      expect(viewModel.error, isNull);
    });

    test('marca la rutina que se está eliminando', () async {
      await viewModel.load();
      final states = <bool>[];
      viewModel.addListener(
        () => states.add(viewModel.isDeletingRoutine(testRoutine)),
      );

      await viewModel.delete(testRoutine, yes);

      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });
  });
}
