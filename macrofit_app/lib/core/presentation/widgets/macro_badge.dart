import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/macro_style.dart';
import '../theme/theme_context.dart';
import 'progress_ring.dart';

/// Ícono de un macronutriente dentro de un anillo con su avance (0 a 1).
class MacroBadge extends StatelessWidget {
  const MacroBadge({
    required this.macro,
    required this.value,
    this.color,
    super.key,
  });

  final Macro macro;
  final double value;

  /// Color del avance (p. ej. advertencia si se pasó de la meta).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return ProgressRing(
      value: value,
      color: color ?? macro.color(app),
      trackColor: macro.track(app),
      size: AppSizes.macroBadge,
      strokeWidth: AppSizes.macroBadgeStroke,
      child: Icon(macro.icon, size: AppSizes.iconXs, color: macro.color(app)),
    );
  }
}
