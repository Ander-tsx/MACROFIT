import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Renglón «Etiqueta ········ valor» (referencia: "Total burned calories").
class LeaderRow extends StatelessWidget {
  const LeaderRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: CustomPaint(
                painter: _DotsPainter(color: colors.outline),
                child: const SizedBox(height: AppSpacing.xxs),
              ),
            ),
          ),
          Flexible(
            flex: 3,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: text.titleMedium?.merge(AppText.numeric),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += AppSizes.dashGap) {
      canvas.drawCircle(Offset(x, y), AppSpacing.xxs / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
