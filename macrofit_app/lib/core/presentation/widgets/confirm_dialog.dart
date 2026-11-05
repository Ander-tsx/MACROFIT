import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'icon_bubble.dart';
import 'primary_button.dart';

/// Diálogo de confirmación de la guía visual. Devuelve `true` solo si la persona
/// confirma; cerrar el diálogo o **Cancelar** devuelven `false`.
///
/// Con [destructive] el botón de confirmar es rojo (eliminar, desvincular).
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        icon: IconBubble(
          icon: icon,
          size: AppSizes.iconBubbleLarge,
          color: destructive ? colors.onErrorContainer : colors.onSurface,
          background: destructive
              ? colors.errorContainer
              : colors.surfaceContainer,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                key: confirmKey,
                label: confirmLabel,
                variant: destructive
                    ? AppButtonVariant.danger
                    : AppButtonVariant.filled,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                key: cancelKey,
                label: cancelLabel,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
