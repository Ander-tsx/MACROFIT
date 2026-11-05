import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Superficie de vidrio líquido: desenfoca y satura lo que pasa por detrás,
/// lleva un tinte translúcido, un brillo especular arriba y un contorno de luz
/// que se desvanece hacia abajo. Se usa en la barra inferior flotante.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.borderRadius = AppRadius.pillAll,
    this.tint,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Color del vidrio; por defecto la superficie del tema.
  final Color? tint;
  final bool shadow;

  /// Matriz de saturación para el filtro del fondo.
  static List<double> _saturate(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final inv = 1 - s;
    return [
      r * inv + s, g * inv, b * inv, 0, 0, //
      r * inv, g * inv + s, b * inv, 0, 0, //
      r * inv, g * inv, b * inv + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final base = tint ?? context.colors.surface;
    const light = AppPalette.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ? AppShadows.floating(context) : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(
              sigmaX: AppGlass.blur,
              sigmaY: AppGlass.blur,
            ),
            inner: ColorFilter.matrix(_saturate(AppGlass.saturation)),
          ),
          child: CustomPaint(
            foregroundPainter: _RimPainter(
              borderRadius: borderRadius,
              top: light.withValues(
                alpha: isDark ? AppGlass.rimTop / 2 : AppGlass.rimTop,
              ),
              bottom: light.withValues(alpha: AppGlass.rimBottom),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: base.withValues(
                  alpha: isDark ? AppGlass.tintDark : AppGlass.tintLight,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, 0.45, 1],
                  colors: [
                    light.withValues(
                      alpha: isDark
                          ? AppGlass.highlight / 3
                          : AppGlass.highlight,
                    ),
                    light.withValues(alpha: 0),
                    light.withValues(alpha: AppGlass.rimBottom / 2),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Contorno de 1 px con degradado vertical (luz arriba, sombra abajo).
class _RimPainter extends CustomPainter {
  const _RimPainter({
    required this.borderRadius,
    required this.top,
    required this.bottom,
  });

  final BorderRadius borderRadius;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(AppSizes.borderThin / 2);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.borderThin
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.top != top ||
      old.bottom != bottom ||
      old.borderRadius != borderRadius;
}
