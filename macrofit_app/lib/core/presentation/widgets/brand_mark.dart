import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/macro_style.dart';
import '../theme/theme_context.dart';

/// Marca de MacroFit: un anillo dividido en los tres macronutrientes (calorías,
/// proteína y grasa) alrededor de un punto lima.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = AppSizes.iconBubbleLarge, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Semantics(
      label: 'MacroFit',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _BrandPainter(
          segments: [for (final macro in Macro.values) macro.color(app)],
          center: app.accent,
        ),
      ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter({required this.segments, required this.center});

  final List<Color> segments;
  final Color center;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    const gap = 0.32;
    final sweep = math.pi * 2 / segments.length;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (final (index, color) in segments.indexed) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + sweep * index + gap / 2,
        sweep - gap,
        false,
        paint..color = color,
      );
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.14,
      Paint()..color = center,
    );
  }

  @override
  bool shouldRepaint(_BrandPainter old) =>
      old.center != center || old.segments != segments;
}
