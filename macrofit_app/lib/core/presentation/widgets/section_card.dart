import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Tarjeta de sección: agrupa un bloque de contenido bajo un título discreto
/// (y opcionalmente una descripción y una acción a la derecha).
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = AppSpacing.cardPaddingLarge,
    this.color,
    this.onTap,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Ícono pequeño junto al título (solo cuando aporta significado).
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final title = this.title;
    final subtitle = this.subtitle;
    final icon = this.icon;
    final hasHeader = title != null || trailing != null;

    return SurfaceCard(
      padding: padding,
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppSizes.iconSm,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Semantics(
                          header: true,
                          child: Text(title, style: text.titleMedium),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle, style: text.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (trailing case final trailing?) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}
