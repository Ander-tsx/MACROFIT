import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../widgets/client_summary_texts.dart';
import 'client_detail_view_model.dart';

/// HU-24 — detalle de un cliente: su resumen y el acceso a sus metas (HU-05)
/// y a sus comidas (HU-25).
class ClientDetailView extends StatelessWidget {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientDetailViewModel>();
    final client = viewModel.client;
    final goal = client.goal;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(client.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (viewModel.isRefreshing) const LinearProgressIndicator(),
            if (viewModel.isUnlinked) ...[
              const ErrorBanner(
                key: Key('client_detail_unlinked'),
                message: 'Este cliente ya no está vinculado contigo.',
              ),
              const SizedBox(height: 12),
            ],
            if (viewModel.error case final message?) ...[
              ErrorBanner(message: message),
              const SizedBox(height: 12),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(client.name, style: textTheme.titleMedium),
              subtitle: Text(client.email),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meta vigente', style: textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(goalSummaryText(goal), style: textTheme.titleMedium),
                    if (goal != null) Text(goalSourceText(goal)),
                    const SizedBox(height: 12),
                    Text(lastMealText(client.lastMealAt, now: DateTime.now())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('client_detail_goals'),
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Metas'),
              subtitle: const Text('Define y ajusta sus calorías y macros'),
              trailing: const Icon(Icons.chevron_right),
              enabled: !viewModel.isUnlinked,
              onTap: () async {
                await context.push(
                  AppRoutes.coachClientGoals(client.id),
                  extra: client,
                );
                // Al regresar se recarga por si le fijó una meta nueva.
                await viewModel.refresh();
              },
            ),
            // TODO(HU-25): abrir el registro diario de comidas del cliente.
            const ListTile(
              key: Key('client_detail_meals'),
              leading: Icon(Icons.restaurant_outlined),
              title: Text('Comidas'),
              subtitle: Text('Disponible próximamente'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}
