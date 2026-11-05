import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'press_scale.dart';

/// Selección única en forma de píldoras (objetivo, nivel, sexo, días...).
///
/// Tocar la opción elegida la deselecciona si [allowDeselect] es `true`, igual
/// que un `SegmentedButton` con `emptySelectionAllowed`.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.keyOf,
    this.allowDeselect = true,
    this.expand = false,
    this.hasError = false,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final String Function(T option) labelOf;

  /// Clave de prueba de cada opción.
  final Key? Function(T option)? keyOf;
  final bool allowDeselect;

  /// Reparte el ancho entre las opciones (todas en una fila).
  final bool expand;

  /// Dibuja el contorno en color de error.
  final bool hasError;

  void _onTap(T option) {
    Haptics.select();
    if (option == selected) {
      if (allowDeselect) onChanged(null);
    } else {
      onChanged(option);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pill(T option) => _Pill(
      key: keyOf?.call(option),
      label: labelOf(option),
      selected: option == selected,
      hasError: hasError,
      onTap: () => _onTap(option),
    );

    if (expand) {
      return Row(
        children: [
          for (final (index, option) in options.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: pill(option)),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final option in options) pill(option)],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.hasError,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = hasError
        ? colors.error
        : selected
        ? colors.primary
        : colors.outlineVariant;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressScale(
        child: Material(
          color: selected ? colors.primary : colors.surface,
          shape: StadiumBorder(side: BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppDurations.normal,
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(
                minHeight: AppSizes.controlCompact,
                minWidth: AppSizes.controlCompact,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.labelLarge?.copyWith(
                  color: selected ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
