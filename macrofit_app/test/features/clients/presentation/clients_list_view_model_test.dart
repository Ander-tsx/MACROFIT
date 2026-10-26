import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/clients/presentation/clients_list/clients_list_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('load trae los clientes vinculados con su resumen', () async {
    final viewModel = ClientsListViewModel(FakeClientsRepository());

    await viewModel.load();

    expect(viewModel.clients, [testClientSummary, testClientWithoutData]);
    expect(viewModel.visibleClients, viewModel.clients);
    expect(viewModel.error, isNull);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasNoClients, isFalse);
  });

  test('la búsqueda filtra por nombre sin hacer otra petición', () async {
    final repository = FakeClientsRepository();
    final viewModel = ClientsListViewModel(repository);
    await viewModel.load();

    viewModel.search('JOSE');
    expect(viewModel.query, 'JOSE');
    expect(viewModel.visibleClients, [testClientWithoutData]);
    expect(viewModel.hasNoMatches, isFalse);

    viewModel.search('Carlos');
    expect(viewModel.visibleClients, isEmpty);
    expect(viewModel.hasNoMatches, isTrue);

    viewModel.search('');
    expect(viewModel.visibleClients, hasLength(2));
    expect(repository.calls, 1);
  });

  test('un coach sin clientes ve la lista vacía y no un error', () async {
    final viewModel = ClientsListViewModel(FakeClientsRepository(clients: []));

    await viewModel.load();

    expect(viewModel.hasNoClients, isTrue);
    expect(viewModel.hasNoMatches, isFalse);
    expect(viewModel.error, isNull);
  });

  test('antes de cargar no se considera una lista vacía', () {
    final viewModel = ClientsListViewModel(FakeClientsRepository(clients: []));
    expect(viewModel.hasNoClients, isFalse);
  });

  test('load muestra el error y permite reintentar', () async {
    final repository = FakeClientsRepository()..error = networkError;
    final viewModel = ClientsListViewModel(repository);

    await viewModel.load();
    expect(viewModel.error, networkError.message);
    expect(viewModel.clients, isEmpty);
    expect(viewModel.hasNoClients, isFalse);

    repository.error = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.clients, hasLength(2));
  });

  test('un error al recargar conserva la lista y la búsqueda', () async {
    final repository = FakeClientsRepository();
    final viewModel = ClientsListViewModel(repository);
    await viewModel.load();
    viewModel.search('ana');

    repository.error = networkError;
    await viewModel.load();

    expect(viewModel.error, networkError.message);
    expect(viewModel.clients, hasLength(2));
    expect(viewModel.visibleClients, [testClientSummary]);
  });
}
