import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'loading_state.dart';

/// Foto que se descarga aparte (historial de comidas): muestra un indicador
/// mientras llega y un ícono si no se pudo cargar.
class AsyncPhoto extends StatelessWidget {
  const AsyncPhoto({
    required this.photo,
    this.semanticLabel = 'Foto de la comida',
    super.key,
  });

  final Future<Uint8List> photo;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: photo,
      builder: (context, snapshot) {
        if (snapshot.data case final bytes?) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            semanticLabel: semanticLabel,
            errorBuilder: (_, _, _) =>
                const PhotoPlaceholder(icon: Icons.broken_image_outlined),
          );
        }
        if (snapshot.hasError) {
          return const PhotoPlaceholder(icon: Icons.broken_image_outlined);
        }
        return const PhotoPlaceholder(child: InlineSpinner());
      },
    );
  }
}

/// Fondo neutro en lugar de una foto (sin foto, cargando o con error).
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({this.icon, this.child, super.key});

  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Center(
        child:
            child ??
            Icon(
              icon ?? Icons.restaurant_rounded,
              color: colors.onSurfaceVariant,
              size: AppSizes.iconLg,
            ),
      ),
    );
  }
}
