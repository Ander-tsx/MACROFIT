import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/charts/chart_data.dart';
import '../../../../core/presentation/widgets/charts/ratio_bars.dart';
import '../../../../core/presentation/widgets/charts/target_bar_chart.dart';
import '../../../../core/presentation/widgets/charts/trend_line_chart.dart';
import '../../../../core/presentation/widgets/choice_pills.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/period_navigator.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../summary/domain/entities/macro_values.dart';
import '../../../summary/domain/usecases/app_day.dart';
import '../../domain/entities/progress_period.dart';
import '../../domain/entities/progress_report.dart';
import 'progress_texts.dart';
import 'progress_view_model.dart';

/// HU-22 — "Mi progreso": gráficas de peso, consumo por día contra la meta y
/// cumplimiento de entrenamiento, por semana o por mes (RF-18).
class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProgressViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Mi progreso'),
      body: SafeArea(
        child: CardEdgeClip(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.huge,
              ),
              children: [
                ChoicePills<ProgressRange>(
                  key: const Key('progress_range'),
                  options: ProgressRange.values,
                  selected: viewModel.range,
                  allowDeselect: false,
                  expand: true,
                  labelOf: (range) => switch (range) {
                    ProgressRange.week => 'Semana',
                    ProgressRange.month => 'Mes',
                  },
                  keyOf: (range) => Key('progress_range_${range.name}'),
                  onChanged: (range) {
                    if (range != null) viewModel.setRange(range);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                PeriodNavigator(
                  label: periodLabel(viewModel.period),
                  previousKey: const Key('progress_previous'),
                  nextKey: const Key('progress_next'),
                  labelKey: const Key('progress_period'),
                  previousTooltip: viewModel.range == ProgressRange.week
                      ? 'Semana anterior'
                      : 'Mes anterior',
                  nextTooltip: viewModel.range == ProgressRange.week
                      ? 'Semana siguiente'
                      : 'Mes siguiente',
                  onPrevious: viewModel.previous,
                  onNext: viewModel.canGoForward ? viewModel.next : null,
                ),
                const SizedBox(height: AppSpacing.cardGap),
                ..._content(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, ProgressViewModel viewModel) {
    final report = viewModel.report;
    if (report == null) {
      if (viewModel.error case final message?) {
        return [
          ErrorState(
            message: message,
            onRetry: viewModel.load,
            retryKey: const Key('progress_retry'),
          ),
        ];
      }
      return const [LoadingState(message: 'Cargando tu progreso…')];
    }

    return [
      // Falló una recarga: se conserva el último reporte y se avisa.
      if (viewModel.error case final message?) ...[
        ErrorBanner(message: message),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          key: const Key('progress_retry'),
          label: 'Reintentar',
          icon: LucideIcons.refreshCw,
          variant: AppButtonVariant.tonal,
          compact: true,
          onPressed: viewModel.load,
        ),
        const SizedBox(height: AppSpacing.cardGap),
      ],
      FadeSlideIn(child: _WeightCard(report: report)),
      const SizedBox(height: AppSpacing.cardGap),
      FadeSlideIn(
        index: 1,
        child: _ConsumptionCard(
          report: report,
          range: viewModel.range,
          macro: viewModel.macro,
          onMacro: viewModel.selectMacro,
        ),
      ),
      const SizedBox(height: AppSpacing.cardGap),
      FadeSlideIn(index: 2, child: _ComplianceCard(report: report)),
    ];
  }
}

/// Peso: el último registro, el cambio del periodo y la tendencia.
class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final weights = report.weights;

    return SectionCard(
      key: const Key('progress_weight'),
      title: 'Peso',
      trailing: PrimaryButton(
        key: const Key('progress_register_weight'),
        label: 'Registrar',
        icon: LucideIcons.plus,
        variant: AppButtonVariant.tonal,
        compact: true,
        expand: false,
        onPressed: () => context.push(AppRoutes.weights),
      ),
      child: report.hasWeightTrend
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: number(weights.last.weightKg),
                    style: text.displaySmall?.merge(AppText.numeric),
                    children: [
                      TextSpan(
                        text: ' kg',
                        style: text.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  weightChangeText(
                    weights.first.weightKg,
                    weights.last.weightKg,
                  ),
                  key: const Key('progress_weight_change'),
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                TrendLineChart(
                  key: const Key('progress_weight_chart'),
                  color: context.appColors.protein,
                  formatValue: (value) => '${number(value)} kg',
                  semanticLabel:
                      'Peso de ${number(weights.first.weightKg)} a '
                      '${number(weights.last.weightKg)} kilos en el periodo',
                  points: [
                    for (final weight in weights)
                      ChartPoint(
                        label: shortDate(appDay(weight.recordedAt)),
                        value: weight.weightKg,
                      ),
                  ],
                ),
              ],
            )
          : const EmptyState(
              key: Key('progress_weight_empty'),
              compact: true,
              icon: LucideIcons.weight,
              title: 'Aún no hay suficientes registros',
              message:
                  'Registra tu peso al menos dos veces en este periodo para '
                  'ver tu tendencia.',
            ),
    );
  }
}

/// Calorías, proteína o grasa por día contra la meta de cada día.
class _ConsumptionCard extends StatelessWidget {
  const _ConsumptionCard({
    required this.report,
    required this.range,
    required this.macro,
    required this.onMacro,
  });

  final ProgressReport report;
  final ProgressRange range;
  final Macro macro;
  final ValueChanged<Macro> onMacro;

  double _of(MacroValues values) => switch (macro) {
    Macro.calories => values.caloriesKcal,
    Macro.protein => values.proteinG,
    Macro.fat => values.fatG,
  };

  String get _unit => macro == Macro.calories ? 'kcal' : 'g';

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final days = report.days;
    final met = days.where((day) => _met(day)).length;

    return SectionCard(
      key: const Key('progress_consumption'),
      title: 'Consumo por día',
      subtitle: 'La barra es lo consumido; la raya, la meta de ese día.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoicePills<Macro>(
            options: Macro.values,
            selected: macro,
            allowDeselect: false,
            expand: true,
            labelOf: (macro) => macro.label,
            keyOf: (macro) => Key('progress_macro_${macro.name}'),
            onChanged: (value) {
              if (value != null) onMacro(value);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          if (report.hasMeals) ...[
            Text(
              'Dentro de la meta: $met de ${days.length} días',
              key: const Key('progress_goal_days'),
              style: text.titleSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TargetBarChart(
              key: Key('progress_chart_${macro.name}'),
              color: macro.color(context.appColors),
              bars: [
                for (final day in days)
                  TargetBar(
                    label: dayAxisLabel(day.date, range),
                    value: _of(day.consumed),
                    target: switch (day.goal) {
                      final goal? => _of(goal),
                      null => null,
                    },
                    met: _met(day),
                    semanticLabel:
                        '${shortDate(day.date)}: ${number(_of(day.consumed))} '
                        '$_unit${switch (day.goal) {
                          final goal? => ' de ${number(_of(goal))} $_unit',
                          null => '',
                        }}',
                  ),
              ],
            ),
          ] else
            const EmptyState(
              key: Key('progress_consumption_empty'),
              compact: true,
              icon: LucideIcons.utensils,
              title: 'Sin comidas registradas',
              message:
                  'Registra tus comidas para comparar tu consumo con tu meta.',
            ),
        ],
      ),
    );
  }

  /// Calorías: la regla del backend (`goal_met`); proteína y grasa: entre el
  /// 90 % y el 110 % de su meta.
  bool _met(ProgressDay day) => macro == Macro.calories
      ? day.goalMet
      : withinGoal(_of(day.consumed), switch (day.goal) {
          final goal? => _of(goal),
          null => null,
        });
}

/// Sesiones completadas por semana contra los días de entrenamiento.
class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final weeks = report.compliance;
    final completed = weeks.fold(0, (sum, w) => sum + w.completedSessions);
    final planned = weeks.fold(0, (sum, w) => sum + w.plannedSessions);

    return SectionCard(
      key: const Key('progress_compliance'),
      title: 'Entrenamiento',
      subtitle: 'Sesiones completadas contra tus días de entrenamiento.',
      child: report.hasCompliance
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$completed de $planned sesiones en el periodo',
                  key: const Key('progress_sessions_total'),
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                RatioBars(
                  key: const Key('progress_compliance_chart'),
                  color: context.appColors.fat,
                  unit: 'sesiones',
                  items: [
                    for (final week in weeks)
                      RatioItem(
                        label:
                            '${shortDate(week.weekStart)} – ${shortDate(week.weekEnd)}',
                        value: week.completedSessions,
                        total: week.plannedSessions,
                      ),
                  ],
                ),
              ],
            )
          : const EmptyState(
              key: Key('progress_compliance_empty'),
              compact: true,
              icon: LucideIcons.dumbbell,
              title: 'Sin días de entrenamiento',
              message:
                  'Define tus días de entrenamiento en tu perfil para medir '
                  'tu cumplimiento.',
            ),
    );
  }
}
