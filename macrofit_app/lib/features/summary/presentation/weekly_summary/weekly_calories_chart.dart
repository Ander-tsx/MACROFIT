import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/day_summary.dart';
import '../../domain/usecases/app_day.dart';
import 'weekly_summary_texts.dart';

/// Calorías consumidas de cada día (barra) contra la meta de ese día (raya). Sobre cada barra
/// va una marca que no depende del color: ✓ si cumplió la meta (`goal_met`) y ✗ si no.
class WeeklyCaloriesChart extends StatelessWidget {
  const WeeklyCaloriesChart({required this.days, super.key});

  final List<DaySummary> days;

  static const _plotHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = days.fold<double>(
      1,
      (peak, day) => math.max(
        peak,
        math.max(day.consumed.caloriesKcal, day.goal.caloriesKcal),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Column(
              key: Key('weekly_day_${day.date}'),
              children: [
                Icon(
                  day.goalMet ? Icons.check_circle : Icons.cancel_outlined,
                  key: Key('weekly_mark_${day.date}'),
                  size: 18,
                  semanticLabel: day.goalMet
                      ? 'Meta cumplida'
                      : 'Meta no cumplida',
                  color: day.goalMet
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: _plotHeight,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      FractionallySizedBox(
                        heightFactor: day.consumed.caloriesKcal / peak,
                        child: Container(
                          key: Key('weekly_bar_${day.date}'),
                          width: 16,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: _plotHeight * day.goal.caloriesKcal / peak,
                        child: Container(
                          key: Key('weekly_goal_${day.date}'),
                          width: 28,
                          height: 3,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(weekdayShort(day.date), style: theme.textTheme.labelSmall),
                Text(
                  '${dayOfMonth(day.date)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
