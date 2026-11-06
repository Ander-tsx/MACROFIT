import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Estado de carga de una pantalla o de una sección: indicador circular y, si se
/// indica, un mensaje que explica qué se está haciendo.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, this.compact = false, super.key});

  final String? message;

  /// Versión para dentro de una tarjeta (menos margen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Semantics(
      liveRegion: true,
      label: message ?? 'Cargando',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: AppSizes.spinnerStroke,
                strokeCap: StrokeCap.round,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador pequeño para dentro de botones y barras.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSizes.spinner,
      child: CircularProgressIndicator(
        strokeWidth: AppSizes.spinnerStroke,
        strokeCap: StrokeCap.round,
        color: color ?? IconTheme.of(context).color,
      ),
    );
  }
}
