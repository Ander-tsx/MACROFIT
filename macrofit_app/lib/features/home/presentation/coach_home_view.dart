import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import 'home_view_model.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/welcome_message.dart';

/// Pantalla principal del rol `coach`. Desde aquí se llega a las metas de sus clientes (HU-05);
/// el resto de su contenido llega con HU-12, HU-24 y siguientes.
class CoachHomeView extends StatelessWidget {
  const CoachHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HomeViewModel>().user;

    return HomeScaffold(
      title: 'Panel de coach',
      actions: [
        IconButton(
          key: const Key('clients_button'),
          tooltip: 'Mis clientes',
          icon: const Icon(Icons.groups),
          onPressed: () => context.push(AppRoutes.coachClients),
        ),
      ],
      body: WelcomeMessage(
        name: user?.name ?? '',
        roleLabel: 'Coach',
        icon: Icons.sports,
        description: 'Aquí verás a tus clientes, sus metas y sus rutinas.',
      ),
    );
  }
}
