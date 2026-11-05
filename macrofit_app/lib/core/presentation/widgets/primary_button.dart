import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'loading_state.dart';
import 'press_scale.dart';

/// Variantes del botón de la guía visual.
enum AppButtonVariant {
  /// Acción principal de la pantalla: píldora de tinta (una por pantalla).
  filled,

  /// Acción secundaria sobre fondo neutro.
  tonal,

  /// Acción alternativa con contorno.
  outlined,

  /// Acción terciaria sin fondo (enlaces, "Cancelar").
  ghost,

  /// Acción destructiva (eliminar, desvincular).
  danger,

  /// Sobre una tarjeta de color: píldora blanca translúcida con texto blanco.
  onColor,
}

/// Botón principal de MacroFit: píldora de 56 px de alto con ícono opcional y
/// estado de carga (muestra un indicador y se deshabilita mientras [isLoading]).
///
/// Se usa en lugar de `FilledButton`/`OutlinedButton`/`TextButton` sueltos para que
/// todas las acciones tengan la misma forma, tamaño y estados.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.expand = true,
    this.compact = false,
    super.key,
  });

  final String label;

  /// `null` deshabilita el botón.
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;

  /// Ocupa todo el ancho disponible.
  final bool expand;

  /// Alto reducido (44 px) para acciones dentro de tarjetas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = isLoading
        ? null
        : withHaptic(onPressed, selection: variant == AppButtonVariant.ghost);
    final size = Size(
      AppSizes.controlCompact,
      compact ? AppSizes.controlCompact : AppSizes.control,
    );
    final padding = EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.lg : AppSpacing.xxl,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const InlineSpinner()
        else if (icon case final icon?)
          Icon(icon),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            child: Text(
              label,
              key: ValueKey(label),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(minimumSize: size, padding: padding),
        child: content,
      ),
      AppButtonVariant.tonal => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: size,
          padding: padding,
          backgroundColor: colors.surfaceContainer,
          foregroundColor: colors.onSurface,
        ),
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: size, padding: padding),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: size, padding: padding),
        child: content,
      ),
      AppButtonVariant.onColor => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          foregroundColor: context.appColors.onFeature,
          backgroundColor: context.appColors.onFeature.withValues(
            alpha: AppOpacity.glass,
          ),
          side: BorderSide(
            color: context.appColors.onFeature.withValues(
              alpha: AppOpacity.muted,
            ),
            width: AppSizes.borderThick,
          ),
        ),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: size,
          padding: padding,
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        child: content,
      ),
    };

    final pressable = PressScale(enabled: onTap != null, child: button);
    return expand
        ? SizedBox(width: double.infinity, child: pressable)
        : pressable;
  }
}
