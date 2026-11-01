import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu progreso de hoy', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._content(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final summary = this.summary;
    final retry = OutlinedButton(
      key: const Key('home_summary_retry'),
      onPressed: onRetry,
      child: const Text('Reintentar'),
    );

    if (summary == null) {
      if (isLoading) {
        return const [Center(child: CircularProgressIndicator())];
      }
      if (error case final message?) {
        return [
          ErrorBanner(message: message),
          const SizedBox(height: 12),
          retry,
        ];
      }
      if (hasNoSummary) {
        return const [
          Text(
            'Cuando tengas una meta verás aquí lo que has consumido hoy.',
            key: Key('home_summary_empty'),
          ),
        ];
      }
      return const [];
    }

    return [
      _MacroProgress(
        keyPrefix: 'home_summary_calories',
        label: 'Calorías',
        unit: 'kcal',
        consumed: summary.consumed.caloriesKcal,
        goal: summary.goal.caloriesKcal,
        remaining: summary.remaining.caloriesKcal,
      ),
      const SizedBox(height: 16),
      _MacroProgress(
        keyPrefix: 'home_summary_protein',
        label: 'Proteína',
        unit: 'g',
        consumed: summary.consumed.proteinG,
        goal: summary.goal.proteinG,
        remaining: summary.remaining.proteinG,
      ),
      const SizedBox(height: 16),
      _MacroProgress(
        keyPrefix: 'home_summary_fat',
        label: 'Grasa',
        unit: 'g',
        consumed: summary.consumed.fatG,
        goal: summary.goal.fatG,
        remaining: summary.remaining.fatG,
      ),
      // Falló una recarga: se conserva el último resumen y se avisa.
      if (error case final message?) ...[
        const SizedBox(height: 12),
        ErrorBanner(message: message),
        const SizedBox(height: 12),
        retry,
      ],
    ];
  }
}

class _MacroProgress extends StatelessWidget {
  const _MacroProgress({
    required this.keyPrefix,
    required this.label,
    required this.unit,
    required this.consumed,
    required this.goal,
    required this.remaining,
  });

  final String keyPrefix;
  final String label;
  final String unit;
  final double consumed;
  final double goal;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exceeded = remaining < 0;
    final color = exceeded
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            Text(
              '${_format(consumed)} / ${_format(goal)} $unit',
              key: Key('${keyPrefix}_values'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          key: Key('${keyPrefix}_bar'),
          value: progressFraction(consumed, goal),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          remainingText(remaining, unit),
          key: Key('${keyPrefix}_remaining'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: exceeded ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
