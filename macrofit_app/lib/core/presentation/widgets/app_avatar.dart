import 'package:blobatar/flutter.dart' as blob;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Avatar de una persona: su [Blobatar](https://blobatar.dev) generado a partir
/// del **correo**, sin fondo (la figura flota sobre la superficie). El mismo
/// correo da siempre el mismo avatar en cualquier dispositivo, sin subir fotos ni
/// guardar nada.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.email,
    this.size = AppSizes.avatar,
    super.key,
  });

  /// Correo de la persona (semilla del avatar).
  final String email;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: blob.Blobatar(
        name: email,
        size: size,
        options: const blob.BlobatarOptions(
          background: blob.Backdrop.none,
          expression: blob.happy,
        ),
      ),
    );
  }
}
