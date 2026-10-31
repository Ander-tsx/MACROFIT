import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
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
      appBar: AppBar(title: const Text('Resumen semanal')),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeekSelector(viewModel: viewModel),
            const SizedBox(height: 16),
            ..._content(context, viewModel),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WeeklySummaryViewModel viewModel,
  ) {
    final summary = viewModel.summary;
    if (summary == null) {
      if (viewModel.isLoading) {
        return const [Center(child: CircularProgressIndicator())];
      }
      if (viewModel.error case final message?) {
        return [
          ErrorBanner(message: message),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('weekly_retry'),
            onPressed: viewModel.load,
            child: const Text('Reintentar'),
          ),
        ];
      }
      if (viewModel.hasNoSummary) {
        return const [
          Text(
            'Cuando tengas una meta verás aquí tu resumen de la semana.',
            key: Key('weekly_empty'),
          ),
        ];
      }
      return const [];
    }

    return [
      if (viewModel.error case final message?) ...[
        ErrorBanner(message: message),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('weekly_retry'),
          onPressed: viewModel.load,
          child: const Text('Reintentar'),
        ),
        const SizedBox(height: 12),
      ],
      _ChartCard(summary: summary),
      const SizedBox(height: 16),
      _StatsCard(summary: summary),
      const SizedBox(height: 16),
      _DaysCard(days: summary.days),
    ];
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.viewModel});

  final WeeklySummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          key: const Key('weekly_previous'),
          tooltip: 'Semana anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: viewModel.previousWeek,
        ),
        Text(
          weekRange(viewModel.start, viewModel.end),
          key: const Key('weekly_range'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const Key('weekly_next'),
          tooltip: 'Semana siguiente',
          icon: const Icon(Icons.chevron_right),
          onPressed: viewModel.canGoForward ? viewModel.nextWeek : null,
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calorías por día', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'La barra es lo consumido; la raya, la meta de ese día. '
              '✓ indica que cumpliste la meta.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            WeeklyCaloriesChart(days: summary.days),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = summary.average;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promedio diario', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Stat(
                  key: const Key('weekly_avg_calories'),
                  label: 'Calorías',
                  value: '${number(average.caloriesKcal)} kcal',
                ),
                _Stat(
                  key: const Key('weekly_avg_protein'),
                  label: 'Proteína',
                  value: '${number(average.proteinG)} g',
                ),
                _Stat(
                  key: const Key('weekly_avg_fat'),
                  label: 'Grasa',
                  value: '${number(average.fatG)} g',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Días con la meta cumplida: ${summary.goalMetDays} de 7',
              key: const Key('weekly_goal_met_days'),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

/// Detalle en texto de cada día: no depende del color ni de leer la gráfica.
class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.days});

  final List<DaySummary> days;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final day in days)
            ListTile(
              key: Key('weekly_row_${day.date}'),
              dense: true,
              leading: Icon(
                day.goalMet ? Icons.check_circle : Icons.cancel_outlined,
              ),
              title: Text('${weekdayShort(day.date)} ${dayMonth(day.date)}'),
              subtitle: Text(
                day.goalMet ? 'Meta cumplida' : 'Meta no cumplida',
              ),
              trailing: Text(
                '${number(day.consumed.caloriesKcal)} / ${number(day.goal.caloriesKcal)} kcal',
              ),
            ),
        ],
      ),
    );
  }
}
