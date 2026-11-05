import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_text.dart';
import '../theme/macro_style.dart';
import '../theme/theme_context.dart';

/// Dato numérico con su etiqueta: «Calorías · 2200 kcal». Si se indica [macro],
/// lleva el punto de color de ese macronutriente.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.macro,
    this.center = false,
    super.key,
  });

  final String label;
  final String value;
  final Macro? macro;

  /// Centra el texto (p. ej. en tres columnas iguales).
  final bool center;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final macro = this.macro;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Con letra grande el valor se reduce en vez de juntarse con el siguiente.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: text.titleLarge?.merge(AppText.numeric)),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (macro != null) ...[
              Container(
                width: AppSizes.dot,
                height: AppSizes.dot,
                decoration: BoxDecoration(
                  color: macro.color(context.appColors),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: text.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
