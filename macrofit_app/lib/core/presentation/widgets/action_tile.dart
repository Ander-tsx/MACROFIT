import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'icon_bubble.dart';

/// Fila de navegación: ícono en círculo, título, descripción y flecha.
///
/// Es un `ListTile` con el estilo de la guía, así que conserva su semántica,
/// su estado deshabilitado ([enabled]) y su área táctil. Va dentro de una
/// tarjeta (`SectionCard` o `Card`).
class ActionTile extends ListTile {
  ActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? iconBackground,
    Widget? trailing,
    super.onTap,
    super.enabled,
    super.key,
  }) : super(
         leading: IconBubble(
           icon: icon,
           color: iconColor,
           background: iconBackground,
         ),
         title: Text(title),
         subtitle: subtitle == null ? null : Text(subtitle),
         trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
         minVerticalPadding: AppSpacing.md,
       );
}
