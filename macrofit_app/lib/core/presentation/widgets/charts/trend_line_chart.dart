import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';
import 'chart_data.dart';

/// Línea de tendencia (p. ej. el peso) con área degradada, el valor mínimo y
/// máximo a la izquierda y la primera y la última fecha abajo. Se dibuja de
/// izquierda a derecha al aparecer.
///
/// Sin estado: recibe todo por parámetro. Necesita al menos dos puntos.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    required this.points,
    required this.color,
    required this.formatValue,
    this.semanticLabel,
    this.height = AppSizes.chartHeight,
    super.key,
  }) : assert(points.length >= 2, 'La tendencia necesita dos puntos');

  final List<ChartPoint> points;
  final Color color;

  /// Texto de un valor del eje vertical (`72.4 kg`).
  final String Function(double value) formatValue;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final values = points.map((point) => point.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final labelStyle = text.labelSmall?.merge(AppText.numeric);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatValue(high), style: labelStyle),
                    Text(formatValue(low), style: labelStyle),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppDurations.rings,
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => CustomPaint(
                      painter: _TrendPainter(
                        values: values.toList(),
                        low: low,
                        high: high,
                        progress: progress,
                        line: color,
                        grid: colors.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(points.first.label, style: labelStyle),
              Text(points.last.label, style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.low,
    required this.high,
    required this.progress,
    required this.line,
    required this.grid,
  });

  final List<double> values;
  final double low;
  final double high;
  final double progress;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    // Líneas guía punteadas arriba, en medio y abajo.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = AppSizes.borderThin;
    for (final y in [0.0, size.height / 2, size.height]) {
      for (var x = 0.0; x < size.width; x += AppSizes.chartDash * 2) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + AppSizes.chartDash, y),
          gridPaint,
        );
      }
    }

    final span = math.max(high - low, 1e-9);
    const pad = AppSpacing.sm;
    Offset point(int i) => Offset(
      size.width * i / (values.length - 1),
      pad + (size.height - pad * 2) * (1 - (values[i] - low) / span),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = point(i - 1);
      final b = point(i);
      final midX = (a.dx + b.dx) / 2;
      path.cubicTo(midX, a.dy, midX, b.dy, b.dx, b.dy);
    }

    // Revela de izquierda a derecha.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            line.withValues(alpha: AppOpacity.track),
            line.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.macroBadgeStroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(
        point(i),
        i == values.length - 1
            ? AppSizes.dot / 2 + AppSpacing.xxs
            : AppSizes.dot / 3,
        Paint()..color = line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.line != line ||
      old.grid != grid;
}
