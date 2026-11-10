import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/routines/presentation/routine_assignments/routine_assignments_view_model.dart';
import 'package:macrofit_app/features/routines/presentation/routine_builder/routine_builder_view_model.dart';
import 'package:macrofit_app/features/routines/presentation/routines_list/routines_list_view_model.dart';
import 'package:macrofit_app/features/routines/presentation/widgets/routine_texts.dart';

import '../../../helpers/fakes.dart';

final ana = testAssignment(clientId: 'cli_ana00001', clientName: 'Ana');
final bruno = testAssignment(clientId: 'cli_bruno0001', clientName: 'Bruno');

Future<bool> yes() async => true;
Future<bool> no() async => false;

void main() {
  late FakeRoutinesRepository repository;

  setUp(() {
    repository = FakeRoutinesRepository(
      assignments: {
        testRoutine.id: [ana, bruno],
      },
    );
  });

  group('clientes asignados (HU-20)', () {
    RoutineAssignmentsViewModel build() => RoutineAssignmentsViewModel(
      repository: repository,
      routine: testRoutine,
    );

    test('muestra los clientes que tienen la rutina', () async {
      final viewModel = build();
      await viewModel.load();

      expect(viewModel.assignments.map((a) => a.clientName), ['Ana', 'Bruno']);
      expect(viewModel.hasNoAssignments, isFalse);
    });

    test('sin asignaciones lo indica (no es un error)', () async {
      repository.assignments = {};
      final viewModel = build();
      await viewModel.load();

      expect(viewModel.hasNoAssignments, isTrue);
      expect(viewModel.error, isNull);
    });

    test(
      'retirar con confirmación llama al DELETE y quita al cliente',
      () async {
        final viewModel = build();
        await viewModel.load();

        final result = await viewModel.remove(ana, yes);

        expect(result, RemoveAssignmentResult.removed);
        expect(repository.removed, [
          (routineId: testRoutine.id, clientId: ana.clientId),
        ]);
        expect(viewModel.assignments.map((a) => a.clientName), ['Bruno']);
      },
    );

    test('cancelar no retira', () async {
      final viewModel = build();
      await viewModel.load();

      final result = await viewModel.remove(ana, no);

      expect(result, RemoveAssignmentResult.cancelled);
      expect(repository.removed, isEmpty);
      expect(viewModel.assignments, hasLength(2));
    });

    test('una asignación ya retirada se quita de la lista e informa', () async {
      final viewModel = build();
      await viewModel.load();
      repository.assignments = {
        testRoutine.id: [bruno],
      };

      final result = await viewModel.remove(ana, yes);

      expect(result, RemoveAssignmentResult.alreadyRemoved);
      expect(viewModel.assignments.map((a) => a.clientName), ['Bruno']);
      expect(viewModel.removeError, isNull);
    });

    test('sin conexión muestra el error y el cliente se queda', () async {
      final viewModel = build();
      await viewModel.load();
      repository.removeError = networkError;

      final result = await viewModel.remove(ana, yes);

      expect(result, RemoveAssignmentResult.failed);
      expect(viewModel.removeError, 'Sin conexión');
      expect(viewModel.assignments, hasLength(2));
      expect(viewModel.isRemoving, isFalse);
    });

    test('si no carga, muestra el error para reintentar', () async {
      repository.assignmentsError = networkError;
      final viewModel = build();
      await viewModel.load();

      expect(viewModel.error, 'Sin conexión');
      expect(viewModel.hasNoAssignments, isFalse);
    });
  });

  group('aviso al editar una rutina asignada (HU-20)', () {
    RoutineBuilderViewModel edit() =>
        RoutineBuilderViewModel(repository: repository, initial: testRoutine);

    test('avisa a cuántos clientes afecta y guarda si se confirma', () async {
      final viewModel = edit();
      int? asked;

      final saved = await viewModel.submit(
        confirmAffected: (count) async {
          asked = count;
          return true;
        },
      );

      expect(asked, 2);
      expect(saved, isTrue);
      expect(repository.updated.single.id, testRoutine.id);
    });

    test('si no se confirma no guarda', () async {
      final viewModel = edit();

      final saved = await viewModel.submit(confirmAffected: (_) async => false);

      expect(saved, isFalse);
      expect(repository.updated, isEmpty);
    });

    test('una rutina sin clientes se guarda sin preguntar', () async {
      repository.assignments = {};
      final viewModel = edit();
      var asked = false;

      final saved = await viewModel.submit(
        confirmAffected: (_) async {
          asked = true;
          return true;
        },
      );

      expect(asked, isFalse);
      expect(saved, isTrue);
    });

    test('al crear no consulta asignaciones', () async {
      final viewModel = RoutineBuilderViewModel(repository: repository)
        ..setName('Nueva')
        ..addExercises([testBenchPress]);

      await viewModel.submit(confirmAffected: (_) async => false);

      expect(repository.assignmentRequests, isEmpty);
      expect(repository.created, hasLength(1));
    });

    test('si no se pudo consultar, guarda sin avisar', () async {
      repository.assignmentsError = networkError;
      final viewModel = edit();

      final saved = await viewModel.submit(confirmAffected: (_) async => false);

      expect(saved, isTrue);
    });
  });

  group('aviso al eliminar una rutina asignada (HU-20)', () {
    test('cuenta los clientes que tienen la rutina', () async {
      final viewModel = RoutinesListViewModel(repository);

      expect(await viewModel.assignedClientsCount(testRoutine), 2);
      expect(await viewModel.assignedClientsCount(testLegRoutine), 0);
    });

    test('si no se pudo consultar devuelve null (aviso general)', () async {
      repository.assignmentsError = networkError;
      final viewModel = RoutinesListViewModel(repository);

      expect(await viewModel.assignedClientsCount(testRoutine), isNull);
    });
  });

  test('textos de HU-20', () {
    expect(clientCountText(1), '1 cliente');
    expect(clientCountText(3), '3 clientes');
    // 18:00 UTC del 5 de noviembre = 12:00 en México.
    expect(assignedDateText(DateTime.utc(2026, 11, 5, 18)), '5/11/2026');
    expect(ApiErrorCode.assignmentNotFound, 'ASSIGNMENT_NOT_FOUND');
  });
}
