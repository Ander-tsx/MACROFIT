import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Limita el ancho del contenido en pantallas anchas (tableta, web) y lo centra.
/// El hijo recibe siempre un ancho fijo (el disponible, hasta el máximo).
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: math.min(constraints.maxWidth, AppSizes.maxContentWidth),
        child: child,
      ),
    ),
  );
}
