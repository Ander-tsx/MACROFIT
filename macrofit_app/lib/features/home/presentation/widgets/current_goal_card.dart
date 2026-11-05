import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/metric_tile.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../goals/domain/entities/nutritional_goal.dart';

/// Origen de la meta (RN-06): `Calculada` o `Definida por tu coach`.
String goalSourceLabel(GoalSource source) => switch (source) {
  GoalSource.system => 'Calculada',
  GoalSource.coach => 'Definida por tu coach',
};

/// HU-26 — meta vigente del usuario: calorías, proteína, grasa y su origen.
class CurrentGoalCard extends StatelessWidget {
  const CurrentGoalCard({
    required this.goal,
    required this.isLoading,
    required this.hasNoGoal,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final NutritionalGoal? goal;
  final bool isLoading;
  final bool hasNoGoal;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    return SectionCard(
      title: 'Tu meta diaria',

      trailing: goal == null ? null : _SourceTag(source: goal.source),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _content(),
      ),
    );
  }

  List<Widget> _content() {
    final goal = this.goal;

    if (goal == null) {
      if (isLoading) return const [LoadingState(compact: true)];
      if (error case final message?) {
        return [
          ErrorState(
            compact: true,
            message: message,
            onRetry: onRetry,
            retryKey: const Key('home_goal_retry'),
          ),
        ];
      }
      if (hasNoGoal) {
        return const [
          EmptyState(
            key: Key('home_goal_empty'),
            compact: true,
            icon: Icons.flag_outlined,
            title: 'Todavía no tienes una meta',
            message: 'Completa tu perfil o pide a tu coach que te asigne una.',
          ),
        ];
      }
      return const [];
    }

    return [
      Row(
        children: [
          Expanded(
            child: MetricTile(
              key: const Key('home_goal_calories'),
              label: Macro.calories.label,
              macro: Macro.calories,
              value: '${goal.calories} kcal',
            ),
          ),
          Expanded(
            child: MetricTile(
              key: const Key('home_goal_protein'),
              label: Macro.protein.label,
              macro: Macro.protein,
              value: '${goal.proteinG} g',
            ),
          ),
          Expanded(
            child: MetricTile(
              key: const Key('home_goal_fat'),
              label: Macro.fat.label,
              macro: Macro.fat,
              value: '${goal.fatG} g',
            ),
          ),
        ],
      ),
      // Falló una recarga: se conserva la última meta y se avisa.
      if (error case final message?) ...[
        const SizedBox(height: AppSpacing.md),
        ErrorBanner(message: message),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const Key('home_goal_retry'),
          label: 'Reintentar',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.tonal,
          compact: true,
          onPressed: onRetry,
        ),
      ],
    ];
  }
}

/// Etiqueta con el origen de la meta.
class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final GoalSource source;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isCoach = source == GoalSource.coach;
    final background = isCoach ? app.infoContainer : app.successContainer;
    final foreground = isCoach ? app.onInfoContainer : app.onSuccessContainer;

    return Container(
      key: const Key('home_goal_source'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCoach ? Icons.sports_rounded : Icons.calculate_rounded,
            size: AppSizes.iconXs,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            goalSourceLabel(source),
            style: context.text.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
