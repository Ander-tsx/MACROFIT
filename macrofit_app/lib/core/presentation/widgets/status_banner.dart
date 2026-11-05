import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import '../theme/lucide_icons.dart';

/// Tono de un mensaje de estado.
enum StatusTone { error, success, info, warning }

/// Mensaje de estado en línea (error, éxito, información o advertencia) con
/// ícono y color propios de cada tono. Los de error y éxito se anuncian al
/// lector de pantalla en cuanto aparecen.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.message,
    this.tone = StatusTone.info,
    this.title,
    this.icon,
    super.key,
  });

  final String message;
  final StatusTone tone;
  final String? title;

  /// Ícono distinto al del tono.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final app = context.appColors;
    final (background, foreground, defaultIcon) = switch (tone) {
      StatusTone.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        LucideIcons.circleAlert,
      ),
      StatusTone.success => (
        app.successContainer,
        app.onSuccessContainer,
        LucideIcons.circleCheck,
      ),
      StatusTone.info => (
        app.infoContainer,
        app.onInfoContainer,
        LucideIcons.info,
      ),
      StatusTone.warning => (
        app.warningContainer,
        app.onWarningContainer,
        LucideIcons.triangleAlert,
      ),
    };
    final title = this.title;

    return Semantics(
      liveRegion: tone == StatusTone.error || tone == StatusTone.success,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: foreground, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  Text(
                    message,
                    style: context.text.bodyMedium?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
