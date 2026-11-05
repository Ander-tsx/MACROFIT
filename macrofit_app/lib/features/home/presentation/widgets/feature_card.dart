import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/surface_card.dart';

/// Acceso grande del panel del coach: ícono, título y descripción. Con
/// [highlighted] usa el fondo oscuro de la marca.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final app = context.appColors;
    final text = context.text;
    final foreground = highlighted ? app.onHero : colors.onSurface;
    final muted = highlighted ? app.onHeroMuted : colors.onSurfaceVariant;

    return SurfaceCard(
      color: highlighted ? app.hero : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.iconBubble,
                height: AppSizes.iconBubble,
                decoration: BoxDecoration(
                  color: highlighted ? app.accent : colors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconSm,
                  color: highlighted ? app.onAccent : colors.onSurface,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, color: muted),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, style: text.titleMedium?.copyWith(color: foreground)),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: text.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}
