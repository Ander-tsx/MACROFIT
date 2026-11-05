import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/presentation/theme/app_tokens.dart';
import '../../../core/presentation/widgets/action_tile.dart';
import '../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../core/presentation/widgets/highlight_card.dart';
import '../../../core/presentation/widgets/surface_card.dart';
import 'widgets/home_dock.dart';
import 'widgets/home_scaffold.dart';
import '../../../core/presentation/theme/lucide_icons.dart';
import '../../../core/presentation/theme/app_images.dart';

/// Pantalla principal del rol `coach`. Desde aquí se llega a su código de invitación (HU-12),
/// a sus clientes (HU-24) y a sus rutinas (HU-18); desde el detalle de cada cliente, a sus
/// metas (HU-05) y comidas (HU-25).
class CoachHomeView extends StatelessWidget {
  const CoachHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeScaffold(
      subtitle: 'Panel de coach',
      avatarKey: const Key('account_button'),
      dock: HomeDock(
        items: [
          DockItem(
            icon: LucideIcons.house,
            selectedIcon: LucideIcons.house,
            label: 'Inicio',
            selected: true,
            onTap: () {},
          ),
          DockItem(
            key: const Key('clients_button'),
            icon: LucideIcons.users,
            selectedIcon: LucideIcons.users,
            label: 'Clientes',
            onTap: () => context.push(AppRoutes.coachClients),
          ),
          DockItem(
            key: const Key('routines_button'),
            icon: LucideIcons.dumbbell,
            label: 'Rutinas',
            onTap: () => context.push(AppRoutes.coachRoutines),
          ),
        ],
        action: DockItem(
          key: const Key('invite_code_button'),
          icon: LucideIcons.qrCode,
          label: 'Mi código de invitación',
          onTap: () => context.push(AppRoutes.coachInviteCode),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xs,
          AppSpacing.screen,
          AppSpacing.bottomBarClearance,
        ),
        children: [
          FadeSlideIn(
            child: HighlightCard(
              key: const Key('invite_code_home_button'),
              title: 'Mi código de invitación',
              description: 'Compártelo para que tus clientes se vinculen.',
              icon: LucideIcons.userPlus,
              image: AppImages.coach,
              onTap: () => context.push(AppRoutes.coachInviteCode),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          FadeSlideIn(
            index: 1,
            child: HighlightCard(
              key: const Key('routines_home_button'),
              title: 'Mis rutinas',
              description: 'Crea y edita las rutinas de tus clientes.',
              icon: LucideIcons.dumbbell,
              image: AppImages.workout,
              tone: HighlightTone.blue,
              onTap: () => context.push(AppRoutes.coachRoutines),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          FadeSlideIn(
            index: 2,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: ActionTile(
                icon: LucideIcons.users,
                title: 'Mis clientes',
                subtitle: 'Sus metas, sus comidas y su progreso.',
                onTap: () => context.push(AppRoutes.coachClients),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
