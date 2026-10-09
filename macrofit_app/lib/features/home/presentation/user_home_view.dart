import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home_view_model.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/welcome_message.dart';

/// Pantalla principal del rol `user`. Su contenido llega con HU-03 en adelante.
class UserHomeView extends StatelessWidget {
  const UserHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HomeViewModel>().user;

    return HomeScaffold(
      title: 'Inicio',
      body: WelcomeMessage(
        name: user?.name ?? '',
        roleLabel: 'Usuario',
        icon: Icons.person,
        description: 'Aquí verás tu progreso, tus comidas y tus rutinas.',
      ),
    );
  }
}
