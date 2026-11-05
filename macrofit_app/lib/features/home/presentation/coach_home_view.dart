import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/presentation/theme/app_tokens.dart';
import '../../../core/presentation/theme/theme_context.dart';
import '../../../core/presentation/widgets/action_tile.dart';
import '../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../core/presentation/widgets/surface_card.dart';
import 'widgets/feature_card.dart';
import 'widgets/home_dock.dart';
import 'widgets/home_scaffold.dart';

/// Pantalla principal del rol `coach`. Desde aquí se llega a su código de invitación (HU-12),
/// a sus clientes (HU-24) y a sus rutinas (HU-18); desde el detalle de cada cliente, a sus
/// metas (HU-05) y comidas (HU-25).
class CoachHomeView extends StatelessWidget {
  const CoachHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeScaffold(
      subtitle: 'Panel de coach',
      dock: HomeDock(
        items: [
          DockItem(
            icon: Icons.home_rounded,
            label: 'Inicio',
            selected: true,
            onTap: () {},
          ),
          DockItem(
            key: const Key('clients_button'),
            icon: Icons.groups_rounded,
            label: 'Clientes',
            onTap: () => context.push(AppRoutes.coachClients),
          ),
          DockItem(
            key: const Key('invite_code_button'),
            icon: Icons.qr_code_rounded,
            label: 'Mi código',
            onTap: () => context.push(AppRoutes.coachInviteCode),
          ),
          DockItem(
            key: const Key('routines_button'),
            icon: Icons.fitness_center_rounded,
            label: 'Rutinas',
            onTap: () => context.push(AppRoutes.coachRoutines),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.bottomBarClearance,
        ),
        children: [
          FadeSlideIn(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: FeatureCard(
                      key: const Key('invite_code_home_button'),
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Mi código de invitación',
                      description: 'Compártelo para sumar clientes.',
                      highlighted: true,
                      onTap: () => context.push(AppRoutes.coachInviteCode),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FeatureCard(
                      key: const Key('routines_home_button'),
                      icon: Icons.fitness_center_rounded,
                      title: 'Mis rutinas',
                      description: 'Crea y edita rutinas.',
                      onTap: () => context.push(AppRoutes.coachRoutines),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            index: 1,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: ActionTile(
                icon: Icons.groups_rounded,
                title: 'Mis clientes',
                subtitle: 'Sus metas, sus comidas y su progreso.',
                onTap: () => context.push(AppRoutes.coachClients),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FadeSlideIn(
            index: 2,
            child: Text(
              'Aquí verás a tus clientes, sus metas y sus rutinas.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
