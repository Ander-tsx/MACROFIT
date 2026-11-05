import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/presentation/theme/app_tokens.dart';
import '../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../core/presentation/widgets/highlight_card.dart';
import '../../../core/presentation/widgets/primary_button.dart';
import 'user_home_view_model.dart';
import 'widgets/current_goal_card.dart';
import 'widgets/daily_progress_card.dart';
import 'widgets/home_dock.dart';
import 'widgets/home_scaffold.dart';
import 'widgets/refresh_on_return.dart';
import '../../../core/presentation/theme/lucide_icons.dart';
import '../../../core/presentation/theme/app_images.dart';

/// Pantalla principal del rol `user`: progreso del día (HU-10) y meta vigente (HU-26).
/// Desde aquí se abren "Mi perfil" (HU-03), "Registrar comida" (HU-06), "Mis comidas"
/// (HU-09), el resumen semanal (HU-11), la vinculación con el coach (HU-13) y el
/// registro de peso (HU-21).
class UserHomeView extends StatelessWidget {
  const UserHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserHomeViewModel>();
    void openMealPhoto() => context.push(AppRoutes.mealPhoto);

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
              icon: LucideIcons.house,
              selectedIcon: LucideIcons.house,
              label: 'Inicio',
              selected: true,
              onTap: () {},
            ),
            DockItem(
              key: const Key('meal_history_button'),
              icon: LucideIcons.utensils,
              selectedIcon: LucideIcons.utensils,
              label: 'Comidas',
              onTap: () => context.push(AppRoutes.mealHistory),
            ),
            DockItem(
              key: const Key('weekly_summary_button'),
              icon: LucideIcons.chartColumn,
              selectedIcon: LucideIcons.chartColumn,
              label: 'Semana',
              onTap: () => context.push(AppRoutes.weeklySummary),
            ),
            DockItem(
              key: const Key('weights_button'),
              icon: LucideIcons.weight,
              selectedIcon: LucideIcons.weight,
              label: 'Peso',
              onTap: () => context.push(AppRoutes.weights),
            ),
          ],
          action: DockItem(
            key: const Key('register_meal_button'),
            icon: LucideIcons.scan,
            label: 'Registrar comida',
            onTap: openMealPhoto,
          ),
        ),
        body: RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              AppSpacing.bottomBarClearance,
            ),
            children: [
              FadeSlideIn(
                child: DailyProgressCard(
                  summary: viewModel.daySummary,
                  isLoading: viewModel.isLoadingSummary,
                  hasNoSummary: viewModel.hasNoSummary,
                  error: viewModel.summaryError,
                  onRetry: viewModel.loadSummary,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
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
              const SizedBox(height: AppSpacing.cardGap),
              FadeSlideIn(
                index: 2,
                child: HighlightCard(
                  title: '¿Qué comiste?',
                  description: 'Tómale una foto y estimamos sus macros.',
                  icon: LucideIcons.scan,
                  image: AppImages.food,
                  onTap: openMealPhoto,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              // HU-13: vinculación con el coach.
              FadeSlideIn(
                index: 3,
                child: HighlightCard(
                  title: 'Tu coach',
                  description:
                      'Vincúlate con su código para que siga tu progreso y '
                      'ajuste tu meta.',
                  icon: LucideIcons.whistle,
                  image: AppImages.coach,
                  tone: HighlightTone.blue,
                  action: PrimaryButton(
                    key: const Key('link_coach_nav_button'),
                    label: 'Vincular con coach',
                    icon: LucideIcons.link,
                    variant: AppButtonVariant.onColor,
                    expand: false,
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
