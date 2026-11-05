import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/surface_card.dart';

/// Invitación a registrar la comida con una foto (acción principal del
/// usuario, HU-06).
class QuickLogBanner extends StatelessWidget {
  const QuickLogBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final colors = context.colors;
    final text = context.text;
    return SurfaceCard(
      radius: AppRadius.pillAll,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: AppSizes.control,
            height: AppSizes.control,
            decoration: BoxDecoration(
              color: app.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              color: app.onAccent,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Qué comiste?', style: text.titleMedium),
                Text(
                  'Tómale una foto y estimamos sus macros',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}
