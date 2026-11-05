import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'list_row.dart';

/// Registro de comida en la lista de un día (referencia: "Log meal"): foto (o
/// ícono si fue captura manual), hora, valores y una acción opcional a la derecha.
///
/// Va dentro de una tarjeta (`MealDayCard`). La usan "Mis comidas" (HU-09) y
/// las comidas de un cliente (HU-25).
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
    return ListRow(
      leading: photo,
      title: time,
      subtitle: values,
      footer: isManual ? const _Tag(label: 'Captura manual') : null,
      action: trailing,
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
