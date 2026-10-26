import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import 'user_home_view_model.dart';
import 'widgets/current_goal_card.dart';
import 'widgets/home_scaffold.dart';

/// Pantalla principal del rol `user`: meta vigente (HU-26). Desde aquí se abren
/// "Mi perfil" (HU-03) y "Registrar comida" (HU-06).
class UserHomeView extends StatelessWidget {
  const UserHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserHomeViewModel>();

    return HomeScaffold<UserHomeViewModel>(
      title: 'Inicio',
      actions: [
        IconButton(
          key: const Key('profile_button'),
          tooltip: 'Mi perfil',
          icon: const Icon(Icons.account_circle),
          onPressed: () async {
            await context.push(AppRoutes.profileEdit);
            if (!context.mounted) return;
            // Al regresar se consulta de nuevo: editar el perfil puede recalcular la meta (HU-04).
            await viewModel.loadGoal();
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('register_meal_button'),
        onPressed: () => context.push(AppRoutes.mealPhoto),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Registrar comida'),
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.loadGoal,
        child: ListView(
          // Abajo deja espacio para el botón flotante de "Registrar comida".
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Hola, ${viewModel.user?.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            CurrentGoalCard(
              goal: viewModel.goal,
              isLoading: viewModel.isLoadingGoal,
              hasNoGoal: viewModel.hasNoGoal,
              error: viewModel.goalError,
              onRetry: viewModel.loadGoal,
            ),
          ],
        ),
      ),
    );
  }
}
