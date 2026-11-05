import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Anillo de progreso con el contenido en el centro (porcentaje, ícono).
/// Se anima al cambiar [value] (de 0 a 1; los valores fuera se recortan).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.color,
    this.size = AppSizes.ring,
    this.strokeWidth = AppSizes.ringStroke,
    this.trackColor,
    this.child,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Widget? child;

  /// Texto para el lector de pantalla (p. ej. «48 % de la meta de calorías»).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? context.colors.surfaceContainer;
    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
        builder: (context, animated, child) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: color,
            track: track,
            strokeWidth: strokeWidth,
          ),
          child: child,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: ExcludeSemantics(child: child)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
