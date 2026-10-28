import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/goals/presentation/coach_clients/coach_clients_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('load trae los clientes vinculados', () async {
    final viewModel = CoachClientsViewModel(FakeCoachGoalsRepository());

    await viewModel.load();

    expect(viewModel.clients, [testClient]);
    expect(viewModel.error, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('load muestra el error y permite reintentar', () async {
    final goals = FakeCoachGoalsRepository()..clientsError = networkError;
    final viewModel = CoachClientsViewModel(goals);

    await viewModel.load();
    expect(viewModel.error, networkError.message);

    goals.clientsError = null;
    await viewModel.load();
    expect(viewModel.error, isNull);
    expect(viewModel.clients, [testClient]);
  });
}
