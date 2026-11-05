import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Tono de una tarjeta destacada.
enum HighlightTone { green, blue }

/// Tarjeta destacada (referencia: "Workouts this week"): color de marca sobre una
/// foto muy tenue, título arriba, descripción abajo y el ícono en una cápsula de
/// vidrio. Invita a una acción; con [onTap] toda la tarjeta es tocable.
class HighlightCard extends StatelessWidget {
  const HighlightCard({
    required this.title,
    required this.icon,
    this.description,
    this.image,
    this.tone = HighlightTone.green,
    this.onTap,
    this.action,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;

  /// Foto de fondo (`assets/images/...`); se ve tenue bajo el color.
  final String? image;
  final HighlightTone tone;
  final VoidCallback? onTap;

  /// Botón opcional bajo la descripción.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    final (deep, light) = switch (tone) {
      HighlightTone.green => (app.featureGreen, app.featureGreenLight),
      HighlightTone.blue => (app.featureBlue, app.featureBlueLight),
    };
    final description = this.description;
    final image = this.image;

    return SurfaceCard(
      color: deep,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.featureCard),
        child: Stack(
          children: [
            if (image != null)
              Positioned.fill(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(
                    AppOpacity.featureImage,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            // Velo de color: más denso donde va el texto, más ligero a la derecha
            // para que la foto respire.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      deep.withValues(alpha: AppOpacity.featureTintStrong),
                      light.withValues(alpha: AppOpacity.featureTintSoft),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              child: _GlassIcon(icon: icon, color: app.onFeature),
            ),
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSizes.iconBubble + AppSpacing.md,
                    ),
                    child: Text(
                      title,
                      style: text.titleLarge?.copyWith(color: app.onFeature),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxxl),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xxxl),
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
    );
  }
}

/// Ícono dentro de una cápsula de vidrio claro.
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppSizes.iconBubble + AppSpacing.sm,
        height: AppSizes.iconBubble + AppSpacing.sm,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppPalette.white.withValues(alpha: AppOpacity.glass),
          border: Border.all(
            color: AppPalette.white.withValues(alpha: AppOpacity.track * 2),
          ),
        ),
        child: Icon(icon, size: AppSizes.iconMd, color: color),
      ),
    );
  }
}
