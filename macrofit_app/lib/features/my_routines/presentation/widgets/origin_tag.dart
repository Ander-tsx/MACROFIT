import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../domain/entities/user_routine.dart';
import 'my_routine_texts.dart';

/// Píldora con el origen de la rutina (RN-08): ícono y texto, no solo color.
class OriginTag extends StatelessWidget {
  const OriginTag({required this.origin, this.coachName, super.key});

  final RoutineOrigin origin;
  final String? coachName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              origin == RoutineOrigin.system
                  ? LucideIcons.sparkles
                  : LucideIcons.whistle,
              size: AppSizes.iconXs,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                originLabel(origin, coachName),
                style: context.text.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
