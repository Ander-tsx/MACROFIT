import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import 'coach_clients_view_model.dart';

/// HU-05 — clientes vinculados del coach.
class CoachClientsView extends StatelessWidget {
  const CoachClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CoachClientsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis clientes')),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, CoachClientsViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: message),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('clients_retry'),
                onPressed: viewModel.load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (viewModel.clients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no tienes clientes vinculados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: viewModel.clients.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final client = viewModel.clients[index];
        return ListTile(
          key: Key('client_${client.id}'),
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(client.name),
          subtitle: Text(client.email),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            AppRoutes.coachClientGoals(client.id),
            extra: client,
          ),
        );
      },
    );
  }
}
