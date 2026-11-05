import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';

/// Columna alta con un nivel de relleno que sube al aparecer (referencia:
/// valores nutricionales). El relleno indica [fill] (de 0 a 1).
class MacroColumnTile extends StatelessWidget {
  const MacroColumnTile({
    required this.label,
    required this.value,
    required this.fill,
    required this.fillColor,
    this.background,
    this.foreground,
    this.mutedForeground,
    super.key,
  });

  final String label;
  final String value;
  final double fill;
  final Color fillColor;
  final Color? background;
  final Color? foreground;
  final Color? mutedForeground;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return ClipRRect(
      borderRadius: AppRadius.xlAll,
      child: ColoredBox(
        color: background ?? colors.surfaceContainerLow,
        child: SizedBox(
          height: AppSizes.macroColumn,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fill.clamp(0, 1).toDouble()),
                  duration: AppDurations.slow,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    heightFactor: value,
                    widthFactor: 1,
                    child: ColoredBox(color: fillColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: text.labelMedium?.copyWith(
                        color: mutedForeground ?? colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: text.titleLarge
                            ?.merge(AppText.numeric)
                            .copyWith(color: foreground ?? colors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
