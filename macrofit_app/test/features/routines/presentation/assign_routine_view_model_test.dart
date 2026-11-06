import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/routines/presentation/assign_routine/assign_routine_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  const bruno = ClientSummary(
    id: '6ac67c747314ad6c71649010',
    name: 'Bruno',
    email: 'bruno@macrofit.test',
  );

  late FakeRoutinesRepository routines;
  late FakeClientsRepository clients;

  AssignRoutineViewModel build() => AssignRoutineViewModel(
    routine: testRoutine,
    routinesRepository: routines,
    clientsRepository: clients,
  );

  setUp(() {
    routines = FakeRoutinesRepository();
    clients = FakeClientsRepository(
      clients: [testClientSummary, bruno, testClientWithoutData],
    );
  });

  Future<bool> accept(List<ClientSummary> _) async => true;

  group('carga', () {
    test(
      'consulta los clientes vinculados y las asignaciones de la rutina',
      () async {
        final viewModel = build();

        await viewModel.load();

        expect(clients.calls, 1);
        expect(routines.assignmentRequests, [testRoutine.id]);
        expect(viewModel.clients.map((c) => c.name), [
          'Ana',
          'Bruno',
          'José Pérez',
        ]);
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.canAssign, isFalse);
      },
    );

    test(
      'un coach sin clientes ve el estado sin clientes y no puede asignar',
      () async {
        clients.clients = [];
        final viewModel = build();

        await viewModel.load();

        expect(viewModel.hasNoClients, isTrue);
        expect(viewModel.canAssign, isFalse);
        expect(viewModel.error, isNull);
      },
    );

    test(
      'sin conexión muestra el mensaje en español y Reintentar vuelve a cargar',
      () async {
        clients.error = networkError;
        final viewModel = build();

        await viewModel.load();

        expect(viewModel.error, 'Sin conexión');
        expect(viewModel.clients, isEmpty);
        expect(viewModel.hasNoClients, isFalse);

        clients.error = null;
        await viewModel.load();

        expect(viewModel.error, isNull);
        expect(viewModel.clients, hasLength(3));
      },
    );

    test('si fallan las asignaciones muestra el error', () async {
      routines.assignmentsError = apiError(
        ApiErrorCode.routineNotFound,
        status: 404,
        message: 'Rutina no encontrada',
      );
      final viewModel = build();

      await viewModel.load();

      expect(viewModel.error, 'Rutina no encontrada');
    });
  });

  group('ya asignados', () {
    test(
      'aparecen marcados, no se pueden seleccionar y no se envían otra vez',
      () async {
        routines.assignments = {
          testRoutine.id: [
            testAssignment(clientId: testClientSummary.id, clientName: 'Ana'),
          ],
        };
        final viewModel = build()..toggle(testClientSummary);
        await viewModel.load();

        viewModel
          ..toggle(testClientSummary)
          ..toggle(bruno);

        expect(viewModel.isAssigned(testClientSummary), isTrue);
        expect(viewModel.isSelected(testClientSummary), isFalse);
        expect(viewModel.selectedClients, [bruno]);

        await viewModel.assign(accept);

        expect(routines.assignCalls.single.clientIds, [bruno.id]);
      },
    );

    test('si todos ya la tienen lo indica', () async {
      routines.assignments = {
        testRoutine.id: [
          for (final client in clients.clients)
            testAssignment(clientId: client.id),
        ],
      };
      final viewModel = build();

      await viewModel.load();

      expect(viewModel.allAssigned, isTrue);
      expect(viewModel.canAssign, isFalse);
    });
  });

  group('selección y búsqueda', () {
    test('se marcan varios en orden y se desmarcan', () async {
      final viewModel = build();
      await viewModel.load();

      viewModel
        ..toggle(testClientWithoutData)
        ..toggle(testClientSummary)
        ..toggle(bruno)
        ..toggle(bruno);

      expect(viewModel.selectedClients, [
        testClientWithoutData,
        testClientSummary,
      ]);
      expect(viewModel.selectedCount, 2);
      expect(viewModel.canAssign, isTrue);
    });

    test(
      'la búsqueda filtra por nombre sin acentos y conserva la selección',
      () async {
        final viewModel = build();
        await viewModel.load();
        viewModel.toggle(testClientSummary);

        viewModel.search('jose');

        expect(viewModel.visibleClients, [testClientWithoutData]);
        expect(viewModel.selectedClients, [testClientSummary]);
        expect(clients.calls, 1);

        viewModel.search('zzz');
        expect(viewModel.hasNoMatches, isTrue);
      },
    );
  });

  group('asignar', () {
    test('confirma con los clientes elegidos, envía sus ids y deja el aviso de éxito', () async {
      final viewModel = build();
      await viewModel.load();
      viewModel
        ..toggle(bruno)
        ..toggle(testClientSummary);
      List<ClientSummary>? confirmed;

      final assigned = await viewModel.assign((selected) async {
        confirmed = selected;
        return true;
      });

      expect(assigned, isTrue);
      expect(confirmed, [bruno, testClientSummary]);
      expect(routines.assignCalls.single.routineId, testRoutine.id);
      expect(routines.assignCalls.single.clientIds, [
        bruno.id,
        testClientSummary.id,
      ]);
      expect(viewModel.successMessage, '«Torso A» se asignó a 2 clientes.');
      expect(viewModel.isAssigned(bruno), isTrue);
      expect(viewModel.selectedCount, 0);
      expect(viewModel.isAssigning, isFalse);
    });

    test('con un cliente el aviso va en singular', () async {
      final viewModel = build();
      await viewModel.load();
      viewModel.toggle(bruno);

      await viewModel.assign(accept);

      expect(viewModel.successMessage, '«Torso A» se asignó a 1 cliente.');
    });

    test('si el coach cancela el resumen no llama a la API', () async {
      final viewModel = build();
      await viewModel.load();
      viewModel.toggle(bruno);

      final assigned = await viewModel.assign((_) async => false);

      expect(assigned, isFalse);
      expect(routines.assignCalls, isEmpty);
      expect(viewModel.selectedClients, [bruno]);
    });

    test('sin clientes elegidos no pide confirmación', () async {
      final viewModel = build();
      await viewModel.load();
      var asked = false;

      final assigned = await viewModel.assign((_) async => asked = true);

      expect(assigned, isFalse);
      expect(asked, isFalse);
      expect(routines.assignCalls, isEmpty);
    });

    test('403 CLIENT_NOT_LINKED dice quién ya no está vinculado, recarga y conserva al resto', () async {
      final viewModel = build();
      await viewModel.load();
      viewModel
        ..toggle(testClientSummary)
        ..toggle(bruno);
      routines.assignError = apiError(
        ApiErrorCode.clientNotLinked,
        status: 403,
        fields: {'client_ids[1]': 'El cliente no está vinculado contigo'},
        message: 'El cliente no está vinculado contigo',
      );
      // Bruno se desvinculó mientras tanto.
      clients.clients = [testClientSummary, testClientWithoutData];

      final assigned = await viewModel.assign(accept);

      expect(assigned, isFalse);
      expect(
        viewModel.error,
        startsWith('Bruno ya no tiene vinculación contigo.'),
      );
      expect(clients.calls, 2);
      expect(routines.assignmentRequests, hasLength(2));
      expect(viewModel.clients, isNot(contains(bruno)));
      expect(viewModel.selectedClients, [testClientSummary]);
      expect(viewModel.canAssign, isTrue);
    });

    test('403 con varios desvinculados los nombra a todos', () async {
      final viewModel = build();
      await viewModel.load();
      viewModel
        ..toggle(testClientSummary)
        ..toggle(bruno)
        ..toggle(testClientWithoutData);
      routines.assignError = apiError(
        ApiErrorCode.clientNotLinked,
        status: 403,
        fields: {'client_ids[0]': 'x', 'client_ids[2]': 'x'},
      );

      await viewModel.assign(accept);

      expect(
        viewModel.error,
        startsWith('Ana y José Pérez ya no tienen vinculación contigo.'),
      );
      expect(viewModel.selectedClients, [bruno]);
    });

    test(
      'sin conexión al asignar muestra el mensaje y conserva la selección',
      () async {
        final viewModel = build();
        await viewModel.load();
        viewModel.toggle(bruno);
        routines.assignError = networkError;

        final assigned = await viewModel.assign(accept);

        expect(assigned, isFalse);
        expect(viewModel.error, 'Sin conexión');
        expect(viewModel.selectedClients, [bruno]);
        expect(viewModel.isAssigned(bruno), isFalse);
        expect(viewModel.canAssign, isTrue);
      },
    );
  });
}
