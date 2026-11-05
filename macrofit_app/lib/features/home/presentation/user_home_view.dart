import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/presentation/theme/app_tokens.dart';
import '../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../core/presentation/widgets/primary_button.dart';
import '../../../core/presentation/widgets/section_card.dart';
import 'user_home_view_model.dart';
import 'widgets/current_goal_card.dart';
import 'widgets/daily_progress_card.dart';
import 'widgets/home_dock.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/quick_log_banner.dart';
import 'widgets/refresh_on_return.dart';

/// Pantalla principal del rol `user`: progreso del día (HU-10) y meta vigente (HU-26).
/// Desde aquí se abren "Mi perfil" (HU-03), "Registrar comida" (HU-06), "Mis comidas"
/// (HU-09), el resumen semanal (HU-11), la vinculación con el coach (HU-13) y el
/// registro de peso (HU-21).
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
        subtitle: 'Así va tu día',
        avatarKey: const Key('profile_button'),
        avatarTooltip: 'Mi perfil',
        onAvatarTap: () => context.push(AppRoutes.profileEdit),
        dock: HomeDock(
          items: [
            DockItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              selected: true,
              onTap: () {},
            ),
            DockItem(
              key: const Key('meal_history_button'),
              icon: Icons.restaurant_menu_rounded,
              label: 'Comidas',
              onTap: () => context.push(AppRoutes.mealHistory),
            ),
            DockItem(
              key: const Key('register_meal_button'),
              icon: Icons.add_a_photo_rounded,
              label: 'Registrar comida',
              primary: true,
              onTap: () => context.push(AppRoutes.mealPhoto),
            ),
            DockItem(
              key: const Key('weekly_summary_button'),
              icon: Icons.bar_chart_rounded,
              label: 'Resumen',
              onTap: () => context.push(AppRoutes.weeklySummary),
            ),
            DockItem(
              key: const Key('weights_button'),
              icon: Icons.monitor_weight_outlined,
              label: 'Peso',
              onTap: () => context.push(AppRoutes.weights),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.bottomBarClearance,
            ),
            children: [
              FadeSlideIn(
                index: 0,
                child: DailyProgressCard(
                  summary: viewModel.daySummary,
                  isLoading: viewModel.isLoadingSummary,
                  hasNoSummary: viewModel.hasNoSummary,
                  error: viewModel.summaryError,
                  onRetry: viewModel.loadSummary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                index: 1,
                child: CurrentGoalCard(
                  goal: viewModel.goal,
                  isLoading: viewModel.isLoadingGoal,
                  hasNoGoal: viewModel.hasNoGoal,
                  error: viewModel.goalError,
                  onRetry: viewModel.loadGoal,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                index: 2,
                child: QuickLogBanner(
                  onTap: () => context.push(AppRoutes.mealPhoto),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // HU-13: vinculación con el coach.
              FadeSlideIn(
                index: 3,
                child: SectionCard(
                  title: 'Tu coach',
                  subtitle:
                      'Vincúlate con el código de tu coach para que siga tu '
                      'progreso y ajuste tu meta.',
                  child: PrimaryButton(
                    key: const Key('link_coach_nav_button'),
                    label: 'Vincular con coach',
                    icon: Icons.link_rounded,
                    variant: AppButtonVariant.tonal,
                    onPressed: () => context.push(AppRoutes.coachLink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
