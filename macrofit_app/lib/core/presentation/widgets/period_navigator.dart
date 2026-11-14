import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'press_scale.dart';
import '../theme/lucide_icons.dart';

/// Cambio de periodo (día o semana) con la píldora central de la referencia:
/// flecha anterior, «Hoy» y flecha siguiente. Si se pasa [onLabelTap], la
/// píldora abre un selector de fecha.
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
    final labelText = AnimatedSwitcher(
      duration: AppDurations.normal,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(
            begin: AppMotion.pressedScale,
            end: 1.0,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        label,
        key: ValueKey(label),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return Row(
      children: [
        IconButton(
          key: previousKey,
          tooltip: previousTooltip,
          color: colors.onSurfaceVariant,
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: withHaptic(onPrevious, selection: true),
        ),
        Expanded(
          child: PressScale(
            enabled: onLabelTap != null,
            child: Material(
              color: colors.surfaceContainerHigh,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: onLabelTap == null ? null : labelKey,
                onTap: withHaptic(onLabelTap, selection: true),
                child: SizedBox(
                  height: AppSizes.periodPill,
                  child: Center(
                    child: onLabelTap == null
                        ? KeyedSubtree(key: labelKey, child: labelText)
                        : labelText,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: nextKey,
          tooltip: nextTooltip,
          color: colors.onSurfaceVariant,
          icon: const Icon(LucideIcons.chevronRight),
          onPressed: withHaptic(onNext, selection: true),
        ),
      ],
    );
  }
}
