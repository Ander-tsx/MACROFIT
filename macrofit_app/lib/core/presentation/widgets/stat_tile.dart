import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Mosaico de dato con contorno (referencia: "Nutrition info"): etiqueta de
/// color, cifra grande con su unidad, línea y un pie («/2200 kcal»).
///
/// El valor y la unidad forman un solo texto (`2200 kcal`) para lectores de
/// pantalla y pruebas.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.footer,
    this.color,
    this.valueKey,
    super.key,
  });

  final String label;

  /// Cifra principal (`2200`).
  final String value;

  /// Unidad junto a la cifra (`kcal`, `g`).
  final String? unit;

  /// Texto bajo la línea (meta, origen).
  final String? footer;

  /// Color de la etiqueta; por defecto el texto atenuado.
  final Color? color;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final footer = this.footer;
    final unit = this.unit;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.outline, width: AppSizes.tileBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge?.copyWith(
              color: color ?? colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: value,
                style: text.headlineMedium?.merge(AppText.numeric),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: text.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              key: valueKey,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: AppSpacing.sm, color: colors.outline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
