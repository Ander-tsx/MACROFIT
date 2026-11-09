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
import 'widgets/home_scaffold.dart';
import 'widgets/refresh_on_return.dart';
import '../../../core/presentation/theme/lucide_icons.dart';
import '../../../core/presentation/theme/app_images.dart';

/// Pantalla principal del rol `user`: progreso del día (HU-10) y meta vigente (HU-26).
/// Desde aquí se abren "Mi perfil" (HU-03), "Registrar comida" (HU-06), "Mis comidas"
/// (HU-09), el resumen semanal (HU-11), "Mis rutinas" (HU-16), la vinculación con
/// el coach (HU-13) y el registro de peso (HU-21).
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
              // HU-16: rutinas recomendada y asignadas.
              FadeSlideIn(
                index: 3,
                child: HighlightCard(
                  key: const Key('my_routines_home_button'),
                  title: 'Mis rutinas',
                  description:
                      'Tu rutina recomendada y las que te asigna tu coach.',
                  icon: LucideIcons.dumbbell,
                  image: AppImages.workout,
                  onTap: () => context.push(AppRoutes.myRoutines),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              // HU-15: solicitar la rutina recomendada.
              FadeSlideIn(
                index: 4,
                child: HighlightCard(
                  key: const Key('recommended_routine_home_button'),
                  title: 'Rutina recomendada',
                  description: 'Según tu objetivo, tu nivel y tus días de entrenamiento.',
                  icon: LucideIcons.sparkles,
                  image: AppImages.workout,
                  onTap: () => context.push(AppRoutes.recommendedRoutine),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              // HU-13: vinculación con el coach.
              FadeSlideIn(
                index: 5,
                child: HighlightCard(
                  title: 'Tu coach',
                  description: switch (viewModel.linkedCoach) {
                    final coach? =>
                      '${coach.coachName} sigue tu progreso y ajusta tu meta.',
                    null =>
                      'Vincúlate con su código para que siga tu progreso y '
                          'ajuste tu meta.',
                  },
                  icon: LucideIcons.whistle,
                  image: AppImages.coach,
                  tone: HighlightTone.blue,
                  action: PrimaryButton(
                    key: const Key('link_coach_nav_button'),
                    label: viewModel.linkedCoach == null
                        ? 'Vincular con coach'
                        : 'Ver mi coach (${viewModel.linkedCoach!.coachName})',
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
