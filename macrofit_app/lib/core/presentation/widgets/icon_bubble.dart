import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Ícono dentro de un círculo de color: encabeza tarjetas, filas y estados.
class IconBubble extends StatelessWidget {
  const IconBubble({
    required this.icon,
    this.color,
    this.background,
    this.size = AppSizes.iconBubble,
    super.key,
  });

  final IconData icon;

  /// Color del ícono; por defecto el del texto.
  final Color? color;

  /// Color del círculo; por defecto un neutro del tema.
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background ?? colors.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size >= AppSizes.iconBubbleLarge
              ? AppSizes.iconLg
              : AppSizes.iconSm,
          color: color ?? colors.onSurface,
        ),
      ),
    );
  }
}
