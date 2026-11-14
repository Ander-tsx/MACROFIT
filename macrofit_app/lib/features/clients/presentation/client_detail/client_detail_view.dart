import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/action_tile.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../widgets/client_summary_texts.dart';
import 'client_detail_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-24 — detalle de un cliente: su resumen y el acceso a sus metas (HU-05),
/// a sus comidas (HU-25) y a su progreso (HU-23).
class ClientDetailView extends StatelessWidget {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientDetailViewModel>();
    final client = viewModel.client;
    final goal = client.goal;
    final text = context.text;
    final colors = context.colors;

    return Scaffold(
      appBar: AppHeader(title: client.name),
      body: SafeArea(
        child: CardEdgeClip(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.huge,
            ),
            children: [
              AnimatedSize(
                duration: AppDurations.normal,
                child: viewModel.isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: LinearProgressIndicator(
                          minHeight: AppSizes.progressBarThin,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (viewModel.isUnlinked) ...[
                const ErrorBanner(
                  key: Key('client_detail_unlinked'),
                  message: 'Este cliente ya no está vinculado contigo.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (viewModel.error case final message?) ...[
                ErrorBanner(message: message),
                const SizedBox(height: AppSpacing.md),
              ],
              FadeSlideIn(
                child: SurfaceCard(
                  child: Column(
                    children: [
                      AppAvatar(
                        email: client.email,
                        size: AppSizes.avatarLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(client.name, style: text.headlineSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        client.email,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              FadeSlideIn(
                index: 1,
                child: SectionCard(
                  title: 'Meta vigente',
                  trailing: goal == null
                      ? null
                      : _Tag(label: goalSourceText(goal)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goalSummaryText(goal), style: text.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: AppSizes.iconSm,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            lastMealText(
                              client.lastMealAt,
                              now: DateTime.now(),
                            ),
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              FadeSlideIn(
                index: 2,
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: [
                      ActionTile(
                        key: const Key('client_detail_goals'),
                        icon: LucideIcons.flag,
                        title: 'Metas',
                        subtitle: 'Define y ajusta sus calorías y macros',
                        enabled: !viewModel.isUnlinked,
                        onTap: () async {
                          await context.push(
                            AppRoutes.coachClientGoals(client.id),
                            extra: client,
                          );
                          // Al regresar se recarga por si le fijó una meta nueva.
                          await viewModel.refresh();
                        },
                      ),
                      const Divider(
                        height: AppSpacing.xs,
                        indent: AppSpacing.dividerInset,
                      ),
                      ActionTile(
                        key: const Key('client_detail_meals'),
                        icon: LucideIcons.utensils,
                        title: 'Comidas',
                        subtitle: 'Su registro diario de comidas',
                        enabled: !viewModel.isUnlinked,
                        onTap: () async {
                          final unlinked = await context.push<bool>(
                            AppRoutes.coachClientMeals(client.id),
                            extra: client,
                          );
                          if (unlinked == true) {
                            // Ya no está vinculado (HU-25): se regresa a la lista, que se recarga.
                            if (context.mounted) context.pop();
                          } else {
                            await viewModel.refresh();
                          }
                        },
                      ),
                      const Divider(
                        height: AppSpacing.xs,
                        indent: AppSpacing.dividerInset,
                      ),
                      ActionTile(
                        key: const Key('client_detail_progress'),
                        icon: LucideIcons.trendingUp,
                        title: 'Progreso',
                        subtitle: 'Su peso, consumo y entrenamiento',
                        enabled: !viewModel.isUnlinked,
                        onTap: () async {
                          final unlinked = await context.push<bool>(
                            AppRoutes.coachClientProgress(client.id),
                            extra: client,
                          );
                          if (unlinked == true) {
                            // Ya no está vinculado (HU-23, RN-04): se regresa a la lista, que se recarga.
                            if (context.mounted) context.pop();
                          } else {
                            await viewModel.refresh();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(label, style: context.text.labelMedium),
    );
  }
}
