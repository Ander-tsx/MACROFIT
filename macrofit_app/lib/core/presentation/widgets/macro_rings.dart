import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/macro_style.dart';
import '../theme/theme_context.dart';

/// Anillos concéntricos de calorías (afuera), proteína y grasa (adentro), como
/// los anillos de actividad de la referencia. Cada anillo se llena de 0 al
/// valor indicado (0 a 1) y se anima al aparecer o al cambiar.
class MacroRings extends StatelessWidget {
  const MacroRings({
    required this.calories,
    required this.protein,
    required this.fat,
    this.size = AppSizes.macroRings,
    this.strokeWidth = AppSizes.macroRingsStroke,
    this.semanticLabel,
    super.key,
  });

  final double calories;
  final double protein;
  final double fat;
  final double size;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final values = [calories, protein, fat];
    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppDurations.rings,
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingsPainter(
            values: [for (final value in values) value.clamp(0, 1) * progress],
            colors: [for (final macro in Macro.values) macro.color(app)],
            tracks: [for (final macro in Macro.values) macro.track(app)],
            strokeWidth: strokeWidth,
            glow: context.theme.brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({
    required this.values,
    required this.colors,
    required this.tracks,
    required this.strokeWidth,
    required this.glow,
  });

  final List<double> values;
  final List<Color> colors;
  final List<Color> tracks;
  final double strokeWidth;

  /// Resplandor bajo cada arco (solo en oscuro, donde se aprecia).
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final step = strokeWidth + AppSizes.macroRingsGap;

    for (var index = 0; index < values.length; index++) {
      final radius = size.width / 2 - strokeWidth / 2 - step * index;
      if (radius <= 0) break;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = tracks[index]);
      final sweep = math.pi * 2 * values[index];
      if (sweep <= 0) continue;
      final color = colors[index];
      // Degradado a lo largo del arco: empieza más apagado y termina vivo.
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.01),
        colors: [Color.lerp(color, tracks[index], 0.45)!, color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
      if (glow) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: AppOpacity.track * 2)
            ..maskFilter = const MaskFilter.blur(
              BlurStyle.normal,
              AppSpacing.sm,
            ),
        );
      }
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.tracks != tracks ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow;
}
