import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/stat_tile.dart';
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
      child: StateSwitcher(
        stateKey: goal != null
            ? 'data'
            : isLoading
            ? 'loading'
            : error != null
            ? 'error'
            : 'empty',
        child: goal != null ? _content(context, goal) : _state(),
      ),
    );
  }

  Widget _state() {
    if (isLoading) return const LoadingState(compact: true);
    if (error case final message?) {
      return ErrorState(
        compact: true,
        message: message,
        onRetry: onRetry,
        retryKey: const Key('home_goal_retry'),
      );
    }
    if (hasNoGoal) {
      return const EmptyState(
        key: Key('home_goal_empty'),
        compact: true,
        icon: Icons.flag_outlined,
        title: 'Todavía no tienes una meta',
        message: 'Completa tu perfil o pide a tu coach que te asigne una.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _content(BuildContext context, NutritionalGoal goal) {
    final app = context.appColors;
    StatTile tile(Key key, Macro macro, int value, String unit) => StatTile(
      key: key,
      label: macro.label,
      color: macro.color(app),
      value: '$value',
      unit: unit,
      footer: 'al día',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: tile(
                const Key('home_goal_calories'),
                Macro.calories,
                goal.calories,
                'kcal',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: tile(
                const Key('home_goal_protein'),
                Macro.protein,
                goal.proteinG,
                'g',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: tile(
                const Key('home_goal_fat'),
                Macro.fat,
                goal.fatG,
                'g',
              ),
            ),
          ],
        ),
        // Falló una recarga: se conserva la última meta y se avisa.
        if (error case final message?) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(child: ErrorBanner(message: message)),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            key: const Key('home_goal_retry'),
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.tonal,
            compact: true,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

/// Etiqueta con el origen de la meta.
class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final GoalSource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCoach = source == GoalSource.coach;
    return Container(
      key: const Key('home_goal_source'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCoach ? Icons.sports_rounded : Icons.auto_awesome_rounded,
            size: AppSizes.iconXs,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(goalSourceLabel(source), style: context.text.labelMedium),
        ],
      ),
    );
  }
}
