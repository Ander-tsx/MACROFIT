import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/period_navigator.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/stat_tile.dart';
import '../../domain/entities/day_summary.dart';
import '../../domain/entities/week_summary.dart';
import 'weekly_calories_chart.dart';
import 'weekly_summary_texts.dart';
import 'weekly_summary_view_model.dart';

/// HU-11 — resumen semanal (RF-10): calorías de los 7 días contra la meta de cada día,
/// promedio diario y días con la meta cumplida, con cambio a la semana anterior o siguiente.
class WeeklySummaryView extends StatelessWidget {
  const WeeklySummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WeeklySummaryViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Resumen semanal'),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.huge,
          ),
          children: [
            PeriodNavigator(
              label: weekRange(viewModel.start, viewModel.end),
              previousKey: const Key('weekly_previous'),
              nextKey: const Key('weekly_next'),
              labelKey: const Key('weekly_range'),
              previousTooltip: 'Semana anterior',
              nextTooltip: 'Semana siguiente',
              onPrevious: viewModel.previousWeek,
              onNext: viewModel.canGoForward ? viewModel.nextWeek : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._content(viewModel),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(WeeklySummaryViewModel viewModel) {
    final summary = viewModel.summary;
    if (summary == null) {
      if (viewModel.isLoading) return const [LoadingState()];
      if (viewModel.error case final message?) {
        return [
          ErrorState(
            message: message,
            onRetry: viewModel.load,
            retryKey: const Key('weekly_retry'),
          ),
        ];
      }
      if (viewModel.hasNoSummary) {
        return const [
          EmptyState(
            key: Key('weekly_empty'),
            icon: Icons.bar_chart_rounded,
            title: 'Aún no hay resumen',
            message:
                'Cuando tengas una meta verás aquí tu resumen de la semana.',
          ),
        ];
      }
      return const [];
    }

    return [
      if (viewModel.error case final message?) ...[
        ErrorBanner(message: message),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          key: const Key('weekly_retry'),
          label: 'Reintentar',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.tonal,
          compact: true,
          onPressed: viewModel.load,
        ),
        const SizedBox(height: AppSpacing.cardGap),
      ],
      FadeSlideIn(child: _ChartCard(summary: summary)),
      const SizedBox(height: AppSpacing.cardGap),
      FadeSlideIn(index: 1, child: _StatsCard(summary: summary)),
      const SizedBox(height: AppSpacing.cardGap),
      FadeSlideIn(index: 2, child: _DaysCard(days: summary.days)),
    ];
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Calorías por día',
      subtitle:
          'La barra es lo consumido; la raya, la meta de ese día. '
          '✓ indica que cumpliste la meta.',
      child: WeeklyCaloriesChart(
        days: summary.days,
        average: summary.average.caloriesKcal,
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final average = summary.average;
    StatTile tile(Key key, Macro macro, double value, String unit) => StatTile(
      key: key,
      label: macro.label,
      color: macro.color(app),
      value: number(value),
      unit: unit,
      footer: 'por día',
    );

    return SectionCard(
      title: 'Promedio diario',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: tile(
                  const Key('weekly_avg_calories'),
                  Macro.calories,
                  average.caloriesKcal,
                  'kcal',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: tile(
                  const Key('weekly_avg_protein'),
                  Macro.protein,
                  average.proteinG,
                  'g',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: tile(
                  const Key('weekly_avg_fat'),
                  Macro.fat,
                  average.fatG,
                  'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Días con la meta cumplida: ${summary.goalMetDays} de 7',
            key: const Key('weekly_goal_met_days'),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _Streak(days: summary.days),
        ],
      ),
    );
  }
}

/// Siete segmentos: llenos los días con la meta cumplida.
class _Streak extends StatelessWidget {
  const _Streak({required this.days});

  final List<DaySummary> days;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final colors = context.colors;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: AppDurations.slow,
                height: AppSizes.progressBarThin,
                decoration: BoxDecoration(
                  color: day.goalMet ? app.calories : colors.surfaceContainer,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detalle en texto de cada día: no depende del color ni de leer la gráfica.
class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.days});

  final List<DaySummary> days;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final app = context.appColors;
    return SectionCard(
      title: 'Día por día',
      child: Column(
        children: [
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.lg),
            Row(
              key: Key('weekly_row_${day.date}'),
              children: [
                Icon(
                  day.goalMet ? Icons.check_circle : Icons.cancel_outlined,
                  color: day.goalMet ? app.calories : colors.outline,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weekdayShort(day.date)} ${dayMonth(day.date)}',
                        style: text.titleSmall,
                      ),
                      Text(
                        day.goalMet ? 'Meta cumplida' : 'Meta no cumplida',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${number(day.consumed.caloriesKcal)} / ${number(day.goal.caloriesKcal)} kcal',
                  style: text.titleSmall?.merge(AppText.numeric),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
