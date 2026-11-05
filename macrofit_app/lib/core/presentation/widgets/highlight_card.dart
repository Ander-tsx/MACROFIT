import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Tono de una tarjeta destacada.
enum HighlightTone { green, blue, ember }

/// Tarjeta destacada de color (referencia: "Workouts this week"): degradado,
/// título arriba, descripción abajo y una ilustración abstracta a la derecha
/// con el [icon]. Invita a una acción; con [onTap] toda la tarjeta es tocable.
class HighlightCard extends StatelessWidget {
  const HighlightCard({
    required this.title,
    required this.icon,
    this.description,
    this.tone = HighlightTone.green,
    this.onTap,
    this.action,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final HighlightTone tone;
  final VoidCallback? onTap;

  /// Botón opcional bajo la descripción.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    final (dark, light) = switch (tone) {
      HighlightTone.green => (app.featureGreen, app.featureGreenLight),
      HighlightTone.blue => (app.featureBlue, app.featureBlueLight),
      HighlightTone.ember => (app.featureEmber, app.featureEmberLight),
    };
    final description = this.description;

    return SurfaceCard(
      color: dark,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [dark, light],
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.featureCard),
          child: Stack(
            children: [
              Positioned(
                right: -AppSpacing.huge,
                top: -AppSpacing.xxl,
                child: _Art(icon: icon, color: app.onFeature),
              ),
              Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSizes.featureArt - AppSpacing.xxl,
                      ),
                      child: Text(
                        title,
                        style: text.titleLarge?.copyWith(color: app.onFeature),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.huge),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppSizes.featureArt / 2,
                        ),
                        child: Text(
                          description,
                          style: text.bodyLarge?.copyWith(color: app.onFeature),
                        ),
                      ),
                    ],
                    if (action case final action?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      action,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculos concéntricos translúcidos con el ícono al centro.
class _Art extends StatelessWidget {
  const _Art({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget circle(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: alpha)),
        color: color.withValues(alpha: alpha / 3),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppSizes.featureArt + AppSpacing.huge,
        child: Stack(
          alignment: Alignment.center,
          children: [
            circle(AppSizes.featureArt + AppSpacing.huge, AppOpacity.glass),
            circle(AppSizes.featureArt, AppOpacity.art),
            circle(AppSizes.featureArt - AppSpacing.huge, AppOpacity.track),
            Icon(icon, size: AppSizes.iconXl, color: color),
          ],
        ),
      ),
    );
  }
}
