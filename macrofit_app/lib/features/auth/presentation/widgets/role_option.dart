import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/icon_bubble.dart';

/// Tarjeta seleccionable para elegir el rol en el registro (HU-01).
class RoleOption extends StatelessWidget {
  const RoleOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.hasError,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    final border = hasError
        ? colors.error
        : selected
        ? colors.primary
        : colors.outlineVariant;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBubble(
                      icon: icon,
                      color: selected ? colors.primary : colors.onSurface,
                      background: selected
                          ? colors.onPrimary
                          : colors.surfaceContainer,
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: AppDurations.fast,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: foreground,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  label,
                  style: text.titleMedium?.copyWith(color: foreground),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: text.bodySmall?.copyWith(
                    color: selected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
