import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import '../theme/macro_style.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Total de un día de registros: «Total del día: 793 kcal · P 82.2 g · G 11.4 g».
/// La usan "Mis comidas" (HU-09) y las comidas de un cliente (HU-25).
class DayTotalCard extends StatelessWidget {
  const DayTotalCard({required this.values, super.key});

  /// Valores del día en una línea.
  final String values;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: AppSizes.iconBubble,
            height: AppSizes.iconBubble,
            decoration: BoxDecoration(
              color: Macro.calories.track(app),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Macro.calories.icon,
              size: AppSizes.iconSm,
              color: Macro.calories.color(app),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Total del día: ',
                style: text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: values,
                    style: text.titleSmall?.merge(AppText.numeric),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
