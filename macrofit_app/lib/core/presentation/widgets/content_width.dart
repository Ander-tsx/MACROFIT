import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Limita el ancho del contenido en pantallas anchas (tableta, web) y lo centra.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
      child: child,
    ),
  );
}
