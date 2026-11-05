import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/press_scale.dart';
import '../home_view_model.dart';
import 'account_sheet.dart';

/// Estructura común de las pantallas principales (guía visual, "Pantallas
/// principales"): fondo con resplandor superior, saludo con el avatar, contenido
/// y barra inferior flotante.
///
/// El avatar abre el perfil: en el usuario, **Mi perfil** ([onAvatarTap]); en el
/// coach, la hoja de su cuenta. **Cerrar sesión** vive dentro de ese perfil.
///
/// [T] es el ViewModel que la ruta inyecta (`HomeViewModel` o una subclase, como
/// `UserHomeViewModel`); si no se indica, es `HomeViewModel`.
class HomeScaffold<T extends HomeViewModel> extends StatelessWidget {
  const HomeScaffold({
    required this.subtitle,
    required this.body,
    this.onAvatarTap,
    this.avatarKey,
    this.avatarTooltip = 'Mi cuenta',
    this.dock,
    super.key,
  });

  /// Texto bajo el saludo (p. ej. «Panel de coach»).
  final String subtitle;
  final Widget body;

  /// Acción del avatar; si no se indica, abre la hoja de la cuenta.
  final VoidCallback? onAvatarTap;
  final Key? avatarKey;
  final String avatarTooltip;

  /// Barra inferior con los accesos de la pantalla (`HomeDock`).
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<T>();
    final text = context.text;
    final user = viewModel.user;

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
                  AppSpacing.lg,
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
                              'Hola, ${user?.name ?? ''}',
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
                    Tooltip(
                      message: avatarTooltip,
                      child: Semantics(
                        button: true,
                        label: avatarTooltip,
                        child: PressScale(
                          child: InkResponse(
                            key: avatarKey,
                            radius: AppSizes.avatar,
                            onTap: withHaptic(
                              onAvatarTap ?? () => showAccountSheet<T>(context),
                            ),
                            child: AppAvatar(
                              email: user?.email ?? '',
                              size: AppSizes.avatarHeader,
                            ),
                          ),
                        ),
                      ),
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
