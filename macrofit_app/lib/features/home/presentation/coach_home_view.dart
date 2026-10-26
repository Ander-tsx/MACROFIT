import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import 'home_view_model.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/welcome_message.dart';

/// Pantalla principal del rol `coach`. Desde aquí se llega a su código de invitación (HU-12) y
/// a sus clientes (HU-24); desde el detalle de cada cliente, a sus metas (HU-05) y comidas (HU-25).
class CoachHomeView extends StatelessWidget {
  const CoachHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HomeViewModel>().user;

    return HomeScaffold(
      title: 'Panel de coach',
      actions: [
        IconButton(
          key: const Key('invite_code_button'),
          tooltip: 'Mi código de invitación',
          icon: const Icon(Icons.person_add_alt_1),
          onPressed: () => context.push(AppRoutes.coachInviteCode),
        ),
        IconButton(
          key: const Key('clients_button'),
          tooltip: 'Mis clientes',
          icon: const Icon(Icons.groups),
          onPressed: () => context.push(AppRoutes.coachClients),
        ),
      ],
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WelcomeMessage(
                name: user?.name ?? '',
                roleLabel: 'Coach',
                icon: Icons.sports,
                description:
                    'Aquí verás a tus clientes, sus metas y sus rutinas.',
              ),
              FilledButton.tonalIcon(
                key: const Key('invite_code_home_button'),
                onPressed: () => context.push(AppRoutes.coachInviteCode),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Mi código de invitación'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
