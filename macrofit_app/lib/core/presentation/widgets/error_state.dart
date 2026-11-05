import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'icon_bubble.dart';
import 'primary_button.dart';
import '../theme/lucide_icons.dart';

/// Estado de error de una pantalla o una sección que no se pudo cargar: explica
/// qué pasó y ofrece **Reintentar** sin cerrar la app (RNF-11).
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.onRetry,
    this.retryKey,
    this.title = 'No pudimos cargar la información',
    this.retryLabel = 'Reintentar',
    this.compact = false,
    super.key,
  });

  final String title;

  /// Mensaje que llega de la API o del ViewModel (se muestra tal cual).
  final String message;

  /// `null` deshabilita el botón (p. ej. mientras ya se reintenta).
  final VoidCallback? onRetry;
  final Key? retryKey;
  final String retryLabel;

  /// Versión para dentro de una tarjeta.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final retry = PrimaryButton(
      key: retryKey,
      label: retryLabel,
      icon: LucideIcons.refreshCw,
      onPressed: onRetry,
      variant: compact ? AppButtonVariant.tonal : AppButtonVariant.filled,
      expand: false,
      compact: compact,
    );

    final messageText = Semantics(
      liveRegion: true,
      child: Text(
        message,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
    );

    if (compact) {
      // En una tarjeta: texto a la izquierda y "Reintentar" a la derecha, para
      // que la acción quede a la vista sin desplazarse.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.wifiOff,
                      size: AppSizes.iconSm,
                      color: colors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(title, style: text.titleSmall)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                messageText,
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          retry,
        ],
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBubble(
          icon: LucideIcons.wifiOff,
          size: AppSizes.iconBubbleLarge,
          color: colors.onErrorContainer,
          background: colors.errorContainer,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: text.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        messageText,
        const SizedBox(height: AppSpacing.xl),
        retry,
      ],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: content,
        ),
      ),
    );
  }
}
