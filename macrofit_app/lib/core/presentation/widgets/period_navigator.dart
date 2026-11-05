import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Cambio de periodo (día o semana): anterior, etiqueta y siguiente, dentro de
/// una píldora. Si se pasa [onLabelTap], la etiqueta abre un selector de fecha.
class PeriodNavigator extends StatelessWidget {
  const PeriodNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
    this.onLabelTap,
    this.previousKey,
    this.nextKey,
    this.labelKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPrevious;

  /// `null` deshabilita "siguiente" (no hay periodos futuros).
  final VoidCallback? onNext;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback? onLabelTap;
  final Key? previousKey;
  final Key? nextKey;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onLabelTap = this.onLabelTap;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            IconButton(
              key: previousKey,
              tooltip: previousTooltip,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPrevious,
            ),
            Expanded(
              child: onLabelTap == null
                  ? Text(
                      label,
                      key: labelKey,
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium,
                    )
                  : TextButton.icon(
                      key: labelKey,
                      onPressed: onLabelTap,
                      icon: const Icon(
                        Icons.calendar_today_rounded,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(label),
                    ),
            ),
            IconButton(
              key: nextKey,
              tooltip: nextTooltip,
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
