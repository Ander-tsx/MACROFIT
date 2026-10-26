import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import 'home_view_model.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/welcome_message.dart';

/// Pantalla principal del rol `user`. Su contenido llega con HU-04 en adelante.
/// Desde aquí se abren "Mi perfil" (HU-03) y "Registrar comida" (HU-06).
class UserHomeView extends StatelessWidget {
  const UserHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HomeViewModel>().user;

    return HomeScaffold(
      title: 'Inicio',
      actions: [
        IconButton(
          key: const Key('profile_button'),
          tooltip: 'Mi perfil',
          icon: const Icon(Icons.account_circle),
          onPressed: () => context.push(AppRoutes.profileEdit),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('register_meal_button'),
        onPressed: () => context.push(AppRoutes.mealPhoto),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Registrar comida'),
      ),
      body: WelcomeMessage(
        name: user?.name ?? '',
        roleLabel: 'Usuario',
        icon: Icons.person,
        description: 'Aquí verás tu progreso, tus comidas y tus rutinas.',
      ),
    );
  }
}
