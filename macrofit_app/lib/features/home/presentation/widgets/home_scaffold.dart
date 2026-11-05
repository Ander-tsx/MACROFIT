import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../home_view_model.dart';

/// Estructura común de las pantallas principales (guía visual, "Pantallas
/// principales"): fondo con resplandor superior, saludo con avatar y cierre de
/// sesión, contenido y barra inferior flotante.
///
/// [T] es el ViewModel que la ruta inyecta (`HomeViewModel` o una subclase, como
/// `UserHomeViewModel`); si no se indica, es `HomeViewModel`.
class HomeScaffold<T extends HomeViewModel> extends StatelessWidget {
  const HomeScaffold({
    required this.subtitle,
    required this.body,
    this.onAvatarTap,
    this.avatarKey,
    this.avatarTooltip,
    this.dock,
    super.key,
  });

  /// Texto bajo el saludo (p. ej. «Panel de coach»).
  final String subtitle;
  final Widget body;

  /// Si se indica, el avatar es un botón (p. ej. **Mi perfil**).
  final VoidCallback? onAvatarTap;
  final Key? avatarKey;
  final String? avatarTooltip;

  /// Barra inferior con los accesos de la pantalla (`HomeDock`).
  final Widget? dock;

  Future<void> _confirmLogout(BuildContext context) async {
    final viewModel = context.read<T>();
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este dispositivo?',
      confirmLabel: 'Cerrar sesión',
      icon: Icons.logout_rounded,
      confirmKey: const Key('logout_confirm'),
    );
    if (confirmed) await viewModel.logout();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<T>();
    final text = context.text;
    final name = viewModel.user?.name ?? '';
    final avatar = AppAvatar(name: name);

    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              context.appColors.glow,
              context.theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'Hola, $name',
                              style: text.headlineMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: text.bodyMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onAvatarTap case final onTap?)
                      IconButton(
                        key: avatarKey,
                        tooltip: avatarTooltip,
                        padding: EdgeInsets.zero,
                        onPressed: onTap,
                        icon: avatar,
                      )
                    else
                      avatar,
                    IconButton(
                      key: const Key('logout_button'),
                      tooltip: 'Cerrar sesión',
                      icon: viewModel.isLoggingOut
                          ? const InlineSpinner()
                          : const Icon(Icons.logout_rounded),
                      onPressed: viewModel.isLoggingOut
                          ? null
                          : () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: dock,
    );
  }
}
