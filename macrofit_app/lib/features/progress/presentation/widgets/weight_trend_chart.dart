import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';

/// Línea de tendencia del peso (del más antiguo al más reciente) que se dibuja
/// al aparecer. Solo decora: los valores están en la lista de registros.
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({required this.values, super.key});

  /// Pesos del más antiguo al más reciente.
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = context.appColors.calories;
    return ExcludeSemantics(
      child: SizedBox(
        height: AppSizes.sparkline,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppDurations.rings,
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              values: values,
              progress: progress,
              line: color,
              grid: colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.progress,
    required this.line,
    required this.grid,
  });

  final List<double> values;
  final double progress;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = AppSizes.borderThin;
    for (var x = 0.0; x < size.width; x += AppSizes.chartDash * 2) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + AppSizes.chartDash, size.height / 2),
        gridPaint,
      );
    }
    if (values.length < 2) return;

    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(high - low, 1);
    const pad = AppSpacing.md;
    Offset point(int i) => Offset(
      size.width * i / (values.length - 1),
      pad + (size.height - pad * 2) * (1 - (values[i] - low) / span),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final previous = point(i - 1);
      final current = point(i);
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.macroBadgeStroke
        ..strokeCap = StrokeCap.round,
    );
    if (progress >= 1) {
      canvas.drawCircle(
        point(values.length - 1),
        AppSizes.dot / 2 + AppSpacing.xxs,
        Paint()..color = line,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.line != line ||
      old.grid != grid;
}
