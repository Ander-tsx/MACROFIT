import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Recorta el borde superior del contenido que se desplaza bajo el encabezado
/// con la misma curva que las tarjetas (margen de pantalla y radio de 30 px): al
/// subir, las tarjetas se esconden manteniendo su forma en vez de cortarse en
/// línea recta.
///
/// Solo afecta la franja superior; debajo de ella el contenido (y la sombra de
/// las tarjetas) usa todo el ancho.
class CardEdgeClip extends StatelessWidget {
  const CardEdgeClip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ClipPath(clipper: const _CardEdgeClipper(), child: child);
}

class _CardEdgeClipper extends CustomClipper<Path> {
  const _CardEdgeClipper();

  static const double _margin = AppSpacing.screen;
  static const double _radius = AppRadius.xl;

  @override
  Path getClip(Size size) {
    const corner = Radius.circular(_radius);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, _radius)
      ..lineTo(_margin, _radius)
      ..arcToPoint(const Offset(_margin + _radius, 0), radius: corner)
      ..lineTo(size.width - _margin - _radius, 0)
      ..arcToPoint(Offset(size.width - _margin, _radius), radius: corner)
      ..lineTo(size.width, _radius)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_CardEdgeClipper oldClipper) => false;
}
