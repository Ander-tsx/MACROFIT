import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../auth/domain/entities/role.dart';
import '../home_view_model.dart';

/// Hoja de la cuenta (coach): avatar, nombre, correo, rol y **Cerrar sesión**.
Future<void> showAccountSheet<T extends HomeViewModel>(BuildContext context) {
  final viewModel = context.read<T>();
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => ChangeNotifierProvider<T>.value(
      value: viewModel,
      child: _AccountSheet<T>(),
    ),
  );
}

/// Pide confirmación y cierra la sesión. El router lleva a login y reemplaza la
/// pila (HU-02).
Future<void> confirmLogout(
  BuildContext context,
  Future<void> Function() logout,
) async {
  final confirmed = await showConfirmDialog(
    context: context,
    title: 'Cerrar sesión',
    message: '¿Quieres cerrar tu sesión en este dispositivo?',
    confirmLabel: 'Cerrar sesión',
    icon: LucideIcons.logOut,
    destructive: true,
    confirmKey: const Key('logout_confirm'),
  );
  if (confirmed) await logout();
}

class _AccountSheet<T extends HomeViewModel> extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<T>();
    final user = viewModel.user;
    final text = context.text;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(email: user?.email ?? '', size: AppSizes.avatarLarge),
            const SizedBox(height: AppSpacing.md),
            Text(user?.name ?? '', style: text.headlineSmall),
            Text(
              user?.email ?? '',
              style: text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainer,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(
                user?.role == Role.coach ? 'Coach' : 'Usuario',
                style: text.labelMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              key: const Key('logout_button'),
              label: 'Cerrar sesión',
              icon: LucideIcons.logOut,
              variant: AppButtonVariant.outlined,
              isLoading: viewModel.isLoggingOut,
              onPressed: () => confirmLogout(context, viewModel.logout),
            ),
          ],
        ),
      ),
    );
  }
}
