import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Registro de comida en una lista por día: foto (o ícono si fue captura manual),
/// hora, valores y una acción opcional a la derecha.
///
/// La usan "Mis comidas" (HU-09) y las comidas de un cliente (HU-25).
class MealEntryCard extends StatelessWidget {
  const MealEntryCard({
    required this.time,
    required this.values,
    required this.photo,
    this.isManual = false,
    this.trailing,
    super.key,
  });

  /// Hora del registro (`14:05`).
  final String time;

  /// Valores en una línea (`413 kcal · P 42.2 g · G 4.9 g`).
  final String values;

  /// Foto o marcador (`AsyncPhoto` / `PhotoPlaceholder`).
  final Widget photo;
  final bool isManual;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSizes.thumbnail,
            child: ClipRRect(borderRadius: AppRadius.lgAll, child: photo),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: AppSizes.iconXs,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(time, style: text.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(values, style: text.bodyMedium),
                if (isManual) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _Tag(label: 'Captura manual'),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

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
        child: Text(label, style: context.text.labelMedium),
      ),
    );
  }
}
