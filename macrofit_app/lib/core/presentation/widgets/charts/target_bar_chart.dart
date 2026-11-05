import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';
import 'chart_data.dart';

/// Barras por día con la meta de cada una (una raya). Las barras que cumplen
/// su meta usan el color pleno; las demás, el mismo color atenuado. Con muchos
/// días (un mes) se adelgazan y solo se rotulan algunas.
///
/// Sin estado: recibe todo por parámetro.
class TargetBarChart extends StatelessWidget {
  const TargetBarChart({
    required this.bars,
    required this.color,
    this.height = AppSizes.chartHeight,
    super.key,
  });

  final List<TargetBar> bars;
  final Color color;
  final double height;

  /// Máximo de etiquetas visibles en el eje horizontal.
  static const _maxLabels = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final peak = bars.fold<double>(
      1,
      (peak, bar) => math.max(peak, math.max(bar.value, bar.target ?? 0)),
    );
    final step = (bars.length / _maxLabels).ceil().clamp(1, bars.length);
    final dense = bars.length > _maxLabels;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: Semantics(
                      label: bar.semanticLabel,
                      excludeSemantics: true,
                      child: _Bar(
                        bar: bar,
                        peak: peak,
                        height: height,
                        progress: progress,
                        width: dense
                            ? AppSizes.chartBar / 2
                            : AppSizes.chartBar,
                        color: bar.met
                            ? color
                            : color.withValues(alpha: AppOpacity.muted / 2),
                        targetColor: colors.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final (index, bar) in bars.indexed)
                Expanded(
                  child: Text(
                    index % step == 0 ? bar.label : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: text.labelSmall?.merge(AppText.numeric),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bar,
    required this.peak,
    required this.height,
    required this.progress,
    required this.width,
    required this.color,
    required this.targetColor,
  });

  final TargetBar bar;
  final double peak;
  final double height;
  final double progress;
  final double width;
  final Color color;
  final Color targetColor;

  @override
  Widget build(BuildContext context) {
    final target = bar.target;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height * (bar.value / peak) * progress,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.pillAll,
          ),
        ),
        if (target != null && target > 0)
          Positioned(
            bottom: height * target / peak - AppSizes.chartGoalMarkHeight / 2,
            child: Container(
              width: width + AppSpacing.sm,
              height: AppSizes.chartGoalMarkHeight,
              decoration: BoxDecoration(
                color: targetColor,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
      ],
    );
  }
}
