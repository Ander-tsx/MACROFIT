import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';

/// Esquinas de "visor" sobre la foto de la comida (referencia: escáner de
/// comida). Solo decoran; no reciben toques.
class ScanFrame extends StatelessWidget {
  const ScanFrame({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: CustomPaint(
          painter: _CornersPainter(color: color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const length = AppSpacing.xxxl;
    const radius = AppRadius.lg;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.frameStroke
      ..strokeCap = StrokeCap.round;

    void corner(Offset origin, double dx, double dy) {
      final path = Path()
        ..moveTo(origin.dx, origin.dy + dy * length)
        ..lineTo(origin.dx, origin.dy + dy * radius)
        ..quadraticBezierTo(
          origin.dx,
          origin.dy,
          origin.dx + dx * radius,
          origin.dy,
        )
        ..lineTo(origin.dx + dx * length, origin.dy);
      canvas.drawPath(path, paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}
