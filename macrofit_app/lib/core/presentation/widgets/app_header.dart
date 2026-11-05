import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Encabezado de las pantallas secundarias: botón atrás circular, título y
/// acciones. Sustituye al `AppBar` directo para que todas las pantallas se vean
/// igual.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    this.actions = const [],
    this.backgroundColor,
    super.key,
  });

  final String title;
  final List<Widget> actions;

  /// Fondo distinto al de la pantalla (p. ej. sobre una foto).
  final Color? backgroundColor;

  static const double _height = AppSizes.control + AppSpacing.md;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    return AppBar(
      toolbarHeight: _height,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      leadingWidth: canPop ? AppSizes.control + AppSpacing.lg : null,
      titleSpacing: canPop ? 0 : AppSpacing.screen,
      leading: canPop
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: Center(
                child: BackButton(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
            )
          : null,
      title: Text(title, overflow: TextOverflow.ellipsis),
      actions: actions,
    );
  }
}
