import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../domain/entities/day_summary.dart';
import '../../domain/usecases/app_day.dart';
import 'weekly_summary_texts.dart';

/// Calorías consumidas de cada día (barra) contra la meta de ese día (raya), con
/// una línea punteada del promedio. Sobre cada barra va una marca que no depende
/// del color: ✓ si cumplió la meta (`goal_met`) y ✗ si no.
class WeeklyCaloriesChart extends StatelessWidget {
  const WeeklyCaloriesChart({
    required this.days,
    required this.average,
    super.key,
  });

  final List<DaySummary> days;

  /// Promedio diario de calorías de la semana.
  final double average;

  static const _plotHeight = AppSizes.chartHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final app = context.appColors;
    final text = context.text;
    final peak = days.fold<double>(
      1,
      (peak, day) => math.max(
        peak,
        math.max(day.consumed.caloriesKcal, day.goal.caloriesKcal),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: AppSpacing.xxxl),
            for (final day in days)
              Expanded(
                child: Icon(
                  day.goalMet ? Icons.check_circle : Icons.cancel_outlined,
                  key: Key('weekly_mark_${day.date}'),
                  size: AppSizes.iconSm,
                  semanticLabel: day.goalMet
                      ? 'Meta cumplida'
                      : 'Meta no cumplida',
                  color: day.goalMet ? app.calories : colors.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _plotHeight,
          child: Stack(
            children: [
              // Promedio: línea punteada con su valor a la izquierda.
              Positioned(
                left: 0,
                right: 0,
                bottom: _plotHeight * average / peak - AppSpacing.sm,
                child: Row(
                  children: [
                    SizedBox(
                      width: AppSpacing.xxxl,
                      child: Text(
                        number(average),
                        style: text.labelSmall?.merge(AppText.numeric),
                      ),
                    ),
                    Expanded(
                      child: CustomPaint(
                        painter: _DashedLine(color: colors.outline),
                        child: const SizedBox(height: AppSpacing.md),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: AppSpacing.xxxl),
                  for (final (index, day) in days.indexed)
                    Expanded(
                      child: _DayBar(
                        day: day,
                        peak: peak,
                        index: index,
                        color: day.goalMet
                            ? app.calories
                            : colors.surfaceContainerHighest,
                        goalColor: colors.onSurface,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const SizedBox(width: AppSpacing.xxxl),
            for (final day in days)
              Expanded(
                child: Column(
                  key: Key('weekly_day_${day.date}'),
                  children: [
                    Text(weekdayShort(day.date), style: text.labelMedium),
                    Text(
                      '${dayOfMonth(day.date)}',
                      style: text.labelSmall?.merge(AppText.numeric),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Barra de un día que crece al aparecer, con la raya de la meta.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.peak,
    required this.index,
    required this.color,
    required this.goalColor,
  });

  final DaySummary day;
  final double peak;
  final int index;
  final Color color;
  final Color goalColor;

  @override
  Widget build(BuildContext context) {
    const plot = WeeklyCaloriesChart._plotHeight;
    return SizedBox(
      height: plot,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: day.consumed.caloriesKcal / peak),
            duration: AppDurations.slow + AppMotion.stagger * index,
            curve: Curves.easeOutCubic,
            builder: (context, factor, _) => FractionallySizedBox(
              heightFactor: factor,
              child: Container(
                key: Key('weekly_bar_${day.date}'),
                width: AppSizes.chartBar,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: plot * day.goal.caloriesKcal / peak,
            child: Container(
              key: Key('weekly_goal_${day.date}'),
              width: AppSizes.chartGoalMark,
              height: AppSizes.chartGoalMarkHeight,
              decoration: BoxDecoration(
                color: goalColor,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppSizes.borderThin;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += AppSizes.chartDash * 2) {
      canvas.drawLine(Offset(x, y), Offset(x + AppSizes.chartDash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
