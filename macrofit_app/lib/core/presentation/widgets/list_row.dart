import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'press_scale.dart';

/// Renglón de lista (referencia: "Log meal"): cuadro redondeado con ícono o
/// foto, título y descripción, y a la derecha una acción separada por una línea.
class ListRow extends StatelessWidget {
  const ListRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.footer,
    this.action,
    this.onTap,
    super.key,
  });

  /// Contenido del cuadro de la izquierda (ícono, foto, inicial).
  final Widget leading;
  final String title;
  final String? subtitle;

  /// Línea extra bajo la descripción (p. ej. una etiqueta).
  final Widget? footer;

  /// Acción de la derecha (ícono); se separa con una línea vertical.
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final subtitle = this.subtitle;
    final onTap = this.onTap;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSizes.listTile,
            child: ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: ColoredBox(color: colors.surfaceContainer, child: leading),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (footer case final footer?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  footer,
                ],
              ],
            ),
          ),
          if (action case final action?) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xxl,
              child: VerticalDivider(
                width: AppSpacing.md,
                color: colors.outlineVariant,
              ),
            ),
            action,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return PressScale(
      child: InkWell(
        onTap: withHaptic(onTap),
        borderRadius: AppRadius.lgAll,
        child: row,
      ),
    );
  }
}
