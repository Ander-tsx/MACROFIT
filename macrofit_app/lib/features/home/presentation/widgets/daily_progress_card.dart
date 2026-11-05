import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/count_up_text.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/macro_badge.dart';
import '../../../../core/presentation/widgets/macro_rings.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../summary/domain/entities/day_summary.dart';

/// Texto de lo que falta o del exceso: «Te faltan 120 kcal» / «Te pasaste por 150 kcal».
String remainingText(double remaining, String unit) {
  if (remaining < 0) return 'Te pasaste por ${_format(-remaining)} $unit';
  return 'Te faltan ${_format(remaining)} $unit';
}

/// Número sin decimales sobrantes: `70` y `35.5`.
String _format(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// Fracción de la barra: se llena al llegar a la meta y nunca pasa de 1.
double progressFraction(double consumed, double goal) {
  if (goal <= 0) return consumed > 0 ? 1 : 0;
  return (consumed / goal).clamp(0, 1).toDouble();
}

/// HU-10 — progreso del día: calorías, proteína y grasa contra la meta, con
/// los anillos concéntricos de la guía visual.
class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    required this.summary,
    required this.isLoading,
    required this.hasNoSummary,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final DaySummary? summary;
  final bool isLoading;
  final bool hasNoSummary;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    return SectionCard(
      title: 'Tu progreso de hoy',
      child: StateSwitcher(
        stateKey: summary != null
            ? 'data'
            : isLoading
            ? 'loading'
            : error != null
            ? 'error'
            : 'empty',
        child: summary != null ? _content(summary) : _state(),
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
        retryKey: const Key('home_summary_retry'),
      );
    }
    if (hasNoSummary) {
      return const EmptyState(
        key: Key('home_summary_empty'),
        compact: true,
        icon: Icons.donut_large_rounded,
        title: 'Aún no hay progreso que mostrar',
        message: 'Cuando tengas una meta verás aquí lo que has consumido hoy.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _content(DaySummary summary) {
    final consumed = summary.consumed;
    final goal = summary.goal;
    final remaining = summary.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MacroLine(
                    keyPrefix: 'home_summary_calories',
                    macro: Macro.calories,
                    unit: 'kcal',
                    consumed: consumed.caloriesKcal,
                    goal: goal.caloriesKcal,
                    remaining: remaining.caloriesKcal,
                    badgeKey: false,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MacroLine(
                    keyPrefix: 'home_summary_protein',
                    macro: Macro.protein,
                    unit: 'g',
                    consumed: consumed.proteinG,
                    goal: goal.proteinG,
                    remaining: remaining.proteinG,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MacroLine(
                    keyPrefix: 'home_summary_fat',
                    macro: Macro.fat,
                    unit: 'g',
                    consumed: consumed.fatG,
                    goal: goal.fatG,
                    remaining: remaining.fatG,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            MacroRings(
              calories: progressFraction(
                consumed.caloriesKcal,
                goal.caloriesKcal,
              ),
              protein: progressFraction(consumed.proteinG, goal.proteinG),
              fat: progressFraction(consumed.fatG, goal.fatG),
              semanticLabel: 'Avance de calorías, proteína y grasa',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _CaloriesBar(
          consumed: consumed.caloriesKcal,
          goal: goal.caloriesKcal,
          exceeded: remaining.caloriesKcal < 0,
        ),
        // Falló una recarga: se conserva el último resumen y se avisa.
        if (error case final message?) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(child: ErrorBanner(message: message)),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            key: const Key('home_summary_retry'),
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

/// Un macro: anillo con su ícono, «consumido / meta» y lo que falta.
class _MacroLine extends StatelessWidget {
  const _MacroLine({
    required this.keyPrefix,
    required this.macro,
    required this.unit,
    required this.consumed,
    required this.goal,
    required this.remaining,
    this.badgeKey = true,
  });

  final String keyPrefix;
  final Macro macro;
  final String unit;
  final double consumed;
  final double goal;
  final double remaining;

  /// La barra de calorías va aparte; proteína y grasa usan el anillo.
  final bool badgeKey;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final warning = context.appColors.warning;
    final exceeded = remaining < 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MacroBadge(
          key: badgeKey ? Key('${keyPrefix}_bar') : null,
          macro: macro,
          value: progressFraction(consumed, goal),
          color: exceeded ? warning : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value: consumed,
                  builder: (context, value) => Text.rich(
                    TextSpan(
                      text: _format(value),
                      style: text.headlineSmall?.merge(AppText.numeric),
                      children: [
                        TextSpan(
                          text: ' / ${_format(goal)} $unit',
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    key: Key('${keyPrefix}_values'),
                  ),
                ),
              ),
              Text(
                remainingText(remaining, unit),
                key: Key('${keyPrefix}_remaining'),
                style: text.bodySmall?.copyWith(
                  color: exceeded ? warning : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barra de calorías del día con la escala de 0 a la meta (referencia: "Food").
class _CaloriesBar extends StatelessWidget {
  const _CaloriesBar({
    required this.consumed,
    required this.goal,
    required this.exceeded,
  });

  final double consumed;
  final double goal;
  final bool exceeded;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progressFraction(consumed, goal)),
          duration: AppDurations.rings,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            key: const Key('home_summary_calories_bar'),
            value: value,
            color: exceeded ? app.warning : Macro.calories.color(app),
            backgroundColor: context.colors.surfaceContainer,
            minHeight: AppSizes.progressBarThin,
            semanticsLabel: 'Calorías consumidas contra la meta',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: text.bodySmall),
            Text('Meta ${_format(goal)} kcal', style: text.bodySmall),
          ],
        ),
      ],
    );
  }
}
