import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'surface_card.dart';

/// Total de un día de registros: «Total del día: 793 kcal · P 82.2 g · G 11.4 g»
/// sobre la superficie oscura de la marca. La usan "Mis comidas" (HU-09) y las
/// comidas de un cliente (HU-25).
class DayTotalCard extends StatelessWidget {
  const DayTotalCard({required this.values, super.key});

  /// Valores del día en una línea.
  final String values;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;
    return SurfaceCard(
      color: app.hero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Text.rich(
        TextSpan(
          text: 'Total del día: ',
          style: text.bodyMedium?.copyWith(color: app.onHeroMuted),
          children: [
            TextSpan(
              text: values,
              style: text.titleSmall
                  ?.merge(AppText.numeric)
                  .copyWith(color: app.onHero),
            ),
          ],
        ),
      ),
    );
  }
}
