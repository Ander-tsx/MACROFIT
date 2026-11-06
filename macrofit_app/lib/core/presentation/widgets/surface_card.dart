import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'press_scale.dart';

/// Superficie base de la guía visual: esquinas de 30 px, sin borde; en claro
/// lleva una sombra suave. Si recibe [onTap] reacciona al toque (escala y vibración).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = AppSpacing.cardPaddingLarge,
    this.color,
    this.onTap,
    this.radius = AppRadius.xlAll,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.theme.brightness == Brightness.dark;
    final onTap = this.onTap;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: radius,
        boxShadow: shadow && !isDark ? AppShadows.soft(context) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: withHaptic(onTap),
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}
