import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/clients/presentation/client_detail/client_detail_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('refresh actualiza el resumen del cliente', () async {
    final updated = ClientSummary(
      id: testClientWithoutData.id,
      name: testClientWithoutData.name,
      email: testClientWithoutData.email,
      goal: testClientSummary.goal,
    );
    final viewModel = ClientDetailViewModel(
      repository: FakeClientsRepository(clients: [updated]),
      client: testClientWithoutData,
    );
    expect(viewModel.client.goal, isNull);

    await viewModel.refresh();

    expect(viewModel.client.goal, testClientSummary.goal);
    expect(viewModel.isUnlinked, isFalse);
    expect(viewModel.isRefreshing, isFalse);
  });

  test(
    'si el cliente ya no aparece en la lista, indica que se desvinculó',
    () async {
      final viewModel = ClientDetailViewModel(
        repository: FakeClientsRepository(clients: [testClientWithoutData]),
        client: testClientSummary,
      );

      await viewModel.refresh();

      expect(viewModel.isUnlinked, isTrue);
      expect(viewModel.client, testClientSummary);
    },
  );

  test('un error al recargar conserva los datos y lo informa', () async {
    final viewModel = ClientDetailViewModel(
      repository: FakeClientsRepository()..error = networkError,
      client: testClientSummary,
    );

    await viewModel.refresh();

    expect(viewModel.error, networkError.message);
    expect(viewModel.client, testClientSummary);
    expect(viewModel.isUnlinked, isFalse);
  });
}
