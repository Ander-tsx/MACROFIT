import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

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
              _EmptyArt(icon: icon),
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

/// Ilustración del estado vacío: el ícono dentro de círculos concéntricos que
/// aparecen escalonados.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget ring(double size, double alpha, int order) =>
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppDurations.slow + AppMotion.stagger * order,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainerHigh.withValues(alpha: alpha),
            ),
          ),
        );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppSizes.emptyArt,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ring(AppSizes.emptyArt, AppOpacity.track, 2),
            ring(AppSizes.emptyArtMiddle, AppOpacity.muted / 1.5, 1),
            ring(AppSizes.emptyArtInner, 1, 0),
            Icon(icon, size: AppSizes.iconXl, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
