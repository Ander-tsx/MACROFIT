import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Mensaje de error de un control que no es un campo de texto (selección de
/// rol, objetivo, casilla del aviso). Sin [message] no ocupa espacio.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: context.text.bodySmall?.copyWith(color: context.colors.error),
        ),
      ),
    );
  }
}
