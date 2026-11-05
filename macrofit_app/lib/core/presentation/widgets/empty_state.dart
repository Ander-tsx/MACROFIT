import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'icon_bubble.dart';

/// Estado vacío: no hay datos que mostrar todavía. Explica por qué y, si aplica,
/// ofrece la acción que lo resuelve.
///
/// - Normal: centrado, para ocupar una pantalla o una lista.
/// - [compact]: en fila, para dentro de una tarjeta.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Botones (normalmente `PrimaryButton`) debajo del texto.
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final message = this.message;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onSurfaceVariant, size: AppSizes.iconLg),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: text.titleSmall),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: text.bodySmall),
          ],
          for (final action in actions) ...[
            const SizedBox(height: AppSpacing.md),
            action,
          ],
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBubble(
                icon: icon,
                size: AppSizes.iconBubbleLarge,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (actions.isNotEmpty) const SizedBox(height: AppSpacing.xl),
              for (final (index, action) in actions.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
