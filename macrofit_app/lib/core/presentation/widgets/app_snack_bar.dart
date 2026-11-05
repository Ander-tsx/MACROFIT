import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'status_banner.dart';

/// Aviso breve al pie de la pantalla (éxito, información o error) con el ícono
/// de su tono. Recibe el `ScaffoldMessengerState` para poder usarse después de
/// un `await`, cuando el contexto de la vista ya no existe.
///
/// Con [replaceCurrent] oculta antes el aviso visible.
void showAppSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  StatusTone tone = StatusTone.success,
  bool replaceCurrent = false,
}) {
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: _SnackContent(message: message, tone: tone),
    ),
  );
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({required this.message, required this.tone});

  final String message;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final (icon, color) = switch (tone) {
      StatusTone.success => (Icons.check_circle_rounded, app.accent),
      StatusTone.info => (Icons.info_rounded, app.onHeroMuted),
      StatusTone.warning => (Icons.warning_rounded, app.warning),
      StatusTone.error => (Icons.error_rounded, context.colors.error),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: AppSizes.iconMd),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(message)),
      ],
    );
  }
}
