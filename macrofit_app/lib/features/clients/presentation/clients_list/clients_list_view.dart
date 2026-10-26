import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/client_summary.dart';
import '../widgets/client_summary_texts.dart';
import 'clients_list_view_model.dart';

/// HU-24 — clientes vinculados del coach con búsqueda por nombre.
class ClientsListView extends StatelessWidget {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientsListViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis clientes')),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, ClientsListViewModel viewModel) {
    if (viewModel.clients.isEmpty) {
      if (viewModel.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (viewModel.error case final message?) {
        return _CenteredMessage(
          children: [
            ErrorBanner(message: message),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('clients_retry'),
              onPressed: viewModel.load,
              child: const Text('Reintentar'),
            ),
          ],
        );
      }
      if (viewModel.hasNoClients) {
        return _CenteredMessage(
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Todavía no tienes clientes vinculados.\n'
              'Comparte tu código de invitación para que tus clientes '
              'se vinculen contigo.',
              key: Key('clients_empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('clients_invite_code'),
              onPressed: () => context.push(AppRoutes.coachInviteCode),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ver mi código de invitación'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('clients_reload'),
              onPressed: viewModel.load,
              child: const Text('Actualizar'),
            ),
          ],
        );
      }
    }

    final visible = viewModel.visibleClients;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('clients_search'),
            onChanged: viewModel.search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nombre',
            ),
          ),
        ),
        if (viewModel.error case final message?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ErrorBanner(message: message),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: viewModel.hasNoMatches
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      Text(
                        'Ningún cliente coincide con la búsqueda.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ClientTile(
                      client: visible[index],
                      onTap: () async {
                        final client = visible[index];
                        await context.push(
                          AppRoutes.coachClientDetail(client.id),
                          extra: client,
                        );
                        // Al regresar se recarga por si cambió su meta.
                        await viewModel.load();
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.onTap});

  final ClientSummary client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final goal = client.goal;
    final lastMeal = lastMealText(client.lastMealAt, now: DateTime.now());
    return ListTile(
      key: Key('client_${client.id}'),
      leading: CircleAvatar(child: Text(_initial(client.name))),
      title: Text(client.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goalSummaryText(goal)),
          Text(goal == null ? lastMeal : '${goalSourceText(goal)} · $lastMeal'),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
