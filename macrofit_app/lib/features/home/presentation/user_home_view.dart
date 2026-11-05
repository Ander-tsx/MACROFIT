import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import 'user_home_view_model.dart';
import 'widgets/current_goal_card.dart';
import 'widgets/daily_progress_card.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/refresh_on_return.dart';

/// Pantalla principal del rol `user`: progreso del día (HU-10) y meta vigente (HU-26). Desde aquí se abren
/// "Mi perfil" (HU-03), "Registrar comida" (HU-06) y "Mis comidas" (HU-09).
class UserHomeView extends StatelessWidget {
  const UserHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserHomeViewModel>();

    // Al regresar de cualquier pantalla se consulta de nuevo: editar el perfil puede
    // recalcular la meta (HU-04) y guardar o eliminar una comida cambia el resumen (HU-10).
    return RefreshOnReturn(
      path: AppRoutes.userHome,
      onReturn: viewModel.refresh,
      child: HomeScaffold<UserHomeViewModel>(
        title: 'Inicio',
        actions: [
          IconButton(
            key: const Key('weekly_summary_button'),
            tooltip: 'Resumen semanal',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push(AppRoutes.weeklySummary),
          ),
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
        body: RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: ListView(
            // Abajo deja espacio para el botón flotante de "Registrar comida".
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Hola, ${viewModel.user?.name ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DailyProgressCard(
                summary: viewModel.daySummary,
                isLoading: viewModel.isLoadingSummary,
                hasNoSummary: viewModel.hasNoSummary,
                error: viewModel.summaryError,
                onRetry: viewModel.loadSummary,
              ),
              const SizedBox(height: 16),
              CurrentGoalCard(
                goal: viewModel.goal,
                isLoading: viewModel.isLoadingGoal,
                hasNoGoal: viewModel.hasNoGoal,
                error: viewModel.goalError,
                onRetry: viewModel.loadGoal,
              ),
              const SizedBox(height: 16),
              // HU-09: historial de comidas del día.
              OutlinedButton.icon(
                key: const Key('meal_history_button'),
                onPressed: () => context.push(AppRoutes.mealHistory),
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Mis comidas'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('link_coach_nav_button'),
                onPressed: () => context.push(AppRoutes.coachLink),
                icon: const Icon(Icons.link),
                label: Text(
                  viewModel.linkedCoach == null
                      ? 'Vincular con coach'
                      : 'Ver mi coach (${viewModel.linkedCoach!.coachName})',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
