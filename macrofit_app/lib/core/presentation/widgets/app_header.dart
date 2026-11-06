import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Encabezado de las pantallas secundarias (referencia: "Food"): flecha atrás,
/// título grande en negrita y acciones con íconos simples.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    this.actions = const [],
    this.backgroundColor,
    super.key,
  });

  final String title;
  final List<Widget> actions;

  /// Fondo distinto al de la pantalla.
  final Color? backgroundColor;

  static const double _height = AppSizes.control + AppSpacing.lg;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    return AppBar(
      toolbarHeight: _height,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      titleSpacing: canPop ? 0 : AppSpacing.xxl,
      leading: canPop
          ? const BackButton(
              style: ButtonStyle(
                iconSize: WidgetStatePropertyAll(AppSizes.iconLg),
              ),
            )
          : null,
      title: Text(title, overflow: TextOverflow.ellipsis),
      actions: actions,
    );
  }
}
