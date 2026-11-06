import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';
import 'chart_data.dart';

/// Filas «etiqueta · valor de total» con una barra de avance cada una (p. ej.
/// sesiones completadas por semana). Las barras se llenan al aparecer.
///
/// Sin estado: recibe todo por parámetro.
class RatioBars extends StatelessWidget {
  const RatioBars({
    required this.items,
    required this.color,
    required this.unit,
    super.key,
  });

  final List<RatioItem> items;
  final Color color;

  /// Unidad en plural para el lector de pantalla (`sesiones`).
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: '${item.label}: ${item.value} de ${item.total} $unit',
            excludeSemantics: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.label, style: text.bodyMedium)),
                    Text.rich(
                      TextSpan(
                        text: '${item.value}',
                        style: text.titleMedium?.merge(AppText.numeric),
                        children: [
                          TextSpan(
                            text: ' / ${item.total}',
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: item.total <= 0
                        ? 0
                        : (item.value / item.total).clamp(0, 1).toDouble(),
                  ),
                  duration: AppDurations.slow + AppMotion.stagger * index,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    color: color,
                    backgroundColor: colors.surfaceContainer,
                    minHeight: AppSizes.progressBarThin,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
