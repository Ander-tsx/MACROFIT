import 'package:blobatar/flutter.dart' as blob;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Avatar de una persona: su [Blobatar](https://blobatar.dev) generado a partir
/// del **correo**. El mismo correo da siempre el mismo avatar en cualquier
/// dispositivo, sin subir fotos ni guardar nada.
///
/// Lleva un aro con los tres colores de los macros.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.email,
    this.size = AppSizes.avatar,
    this.ring = true,
    super.key,
  });

  /// Correo de la persona (semilla del avatar).
  final String email;
  final double size;

  /// Aro de color alrededor.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final avatar = blob.Blobatar(
      name: email,
      size: ring ? size - AppSpacing.xs * 2 : size,
      options: const blob.BlobatarOptions(
        background: blob.Backdrop.circle,
        expression: blob.happy,
      ),
    );

    return ExcludeSemantics(
      child: ring
          ? Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [app.calories, app.protein, app.fat, app.calories],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.theme.scaffoldBackgroundColor,
                ),
                child: avatar,
              ),
            )
          : SizedBox.square(dimension: size, child: avatar),
    );
  }
}
