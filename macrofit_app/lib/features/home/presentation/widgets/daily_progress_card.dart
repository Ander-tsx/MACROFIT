import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
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

/// HU-10 — progreso del día: calorías, proteína y grasa contra la meta.
///
/// Con datos es la tarjeta oscura protagonista de la pantalla; mientras carga,
/// sin meta o con error es una tarjeta clara con su estado.
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
    return StateSwitcher(
      stateKey: summary != null
          ? 'data'
          : isLoading
          ? 'loading'
          : error != null
          ? 'error'
          : 'empty',
      child: summary != null
          ? _ProgressHero(summary: summary, error: error, onRetry: onRetry)
          : SectionCard(title: 'Tu progreso de hoy', child: _state()),
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
        icon: Icons.insights_rounded,
        title: 'Aún no hay progreso que mostrar',
        message: 'Cuando tengas una meta verás aquí lo que has consumido hoy.',
      );
    }
    return const SizedBox.shrink();
  }
}

/// Tarjeta oscura con las calorías del día y, debajo, proteína y grasa.
class _ProgressHero extends StatelessWidget {
  const _ProgressHero({
    required this.summary,
    required this.error,
    required this.onRetry,
  });

  final DaySummary summary;
  final String? error;
  final VoidCallback onRetry;

  static const _keyPrefix = 'home_summary_calories';

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    // Sobre el fondo oscuro se usan siempre los tonos claros de los macros.
    const onDark = AppColors.dark;
    final consumed = summary.consumed.caloriesKcal;
    final goal = summary.goal.caloriesKcal;
    final remaining = summary.remaining.caloriesKcal;
    final exceeded = remaining < 0;
    final fraction = progressFraction(consumed, goal);
    final percent = goal <= 0 ? 0 : (consumed / goal * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          color: app.hero,
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tu progreso de hoy',
                      style: text.titleSmall?.copyWith(color: app.onHeroMuted),
                    ),
                  ),
                  _Pill(
                    label: '$percent %',
                    background: exceeded ? onDark.fatContainer : app.accent,
                    foreground: exceeded ? onDark.fat : app.onAccent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  text: _format(consumed),
                  style: text.displaySmall
                      ?.merge(AppText.numeric)
                      .copyWith(color: app.onHero),
                  children: [
                    TextSpan(
                      text: ' / ${_format(goal)} kcal',
                      style: text.titleMedium?.copyWith(color: app.onHeroMuted),
                    ),
                  ],
                ),
                key: const Key('${_keyPrefix}_values'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Bar(
                barKey: const Key('${_keyPrefix}_bar'),
                value: fraction,
                color: exceeded ? onDark.fat : app.accent,
                track: app.heroGlass,
                thick: true,
                label: 'Calorías consumidas contra la meta',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                remainingText(remaining, 'kcal'),
                key: const Key('${_keyPrefix}_remaining'),
                style: text.bodySmall?.copyWith(
                  color: exceeded ? onDark.fat : app.onHeroMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MacroColumn(
                      keyPrefix: 'home_summary_protein',
                      macro: Macro.protein,
                      consumed: summary.consumed.proteinG,
                      goal: summary.goal.proteinG,
                      remaining: summary.remaining.proteinG,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: _MacroColumn(
                      keyPrefix: 'home_summary_fat',
                      macro: Macro.fat,
                      consumed: summary.consumed.fatG,
                      goal: summary.goal.fatG,
                      remaining: summary.remaining.fatG,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Falló una recarga: se conserva el último resumen y se avisa.
        if (error case final message?) ...[
          const SizedBox(height: AppSpacing.md),
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

/// Proteína o grasa sobre la tarjeta oscura: valores, barra fina y restante.
class _MacroColumn extends StatelessWidget {
  const _MacroColumn({
    required this.keyPrefix,
    required this.macro,
    required this.consumed,
    required this.goal,
    required this.remaining,
  });

  final String keyPrefix;
  final Macro macro;
  final double consumed;
  final double goal;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    const onDark = AppColors.dark;
    final exceeded = remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(macro.icon, size: AppSizes.iconXs, color: macro.color(onDark)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              macro.label,
              style: text.labelMedium?.copyWith(color: app.onHeroMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${_format(consumed)} / ${_format(goal)} g',
            key: Key('${keyPrefix}_values'),
            style: text.titleMedium
                ?.merge(AppText.numeric)
                .copyWith(color: app.onHero),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Bar(
          barKey: Key('${keyPrefix}_bar'),
          value: progressFraction(consumed, goal),
          color: exceeded ? onDark.fat : macro.color(onDark),
          track: app.heroGlass,
          label: '${macro.label} consumida contra la meta',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          remainingText(remaining, 'g'),
          key: Key('${keyPrefix}_remaining'),
          style: text.bodySmall?.copyWith(
            color: exceeded ? onDark.fat : app.onHeroMuted,
          ),
        ),
      ],
    );
  }
}

/// Barra de progreso que se llena con suavidad desde cero.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.barKey,
    required this.value,
    required this.color,
    required this.track,
    required this.label,
    this.thick = false,
  });

  final Key barKey;
  final double value;
  final Color color;
  final Color track;
  final String label;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => LinearProgressIndicator(
        key: barKey,
        value: animated,
        color: color,
        backgroundColor: track,
        minHeight: thick ? AppSizes.progressBar : AppSizes.dot,
        semanticsLabel: label,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: context.text.labelLarge
            ?.merge(AppText.numeric)
            .copyWith(color: foreground),
      ),
    );
  }
}
