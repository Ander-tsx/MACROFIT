import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/press_scale.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../domain/entities/client_summary.dart';
import '../widgets/client_summary_texts.dart';
import 'clients_list_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-24 — clientes vinculados del coach con búsqueda por nombre.
class ClientsListView extends StatelessWidget {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientsListViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Mis clientes'),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, ClientsListViewModel viewModel) {
    if (viewModel.clients.isEmpty) {
      if (viewModel.isLoading) return const LoadingState();
      if (viewModel.error case final message?) {
        return ErrorState(
          message: message,
          onRetry: viewModel.load,
          retryKey: const Key('clients_retry'),
        );
      }
      if (viewModel.hasNoClients) {
        return EmptyState(
          key: const Key('clients_empty'),
          icon: LucideIcons.userPlus,
          title: 'Todavía no tienes clientes vinculados.',
          message:
              'Comparte tu código de invitación para que tus clientes se '
              'vinculen contigo.',
          actions: [
            PrimaryButton(
              key: const Key('clients_invite_code'),
              label: 'Ver mi código de invitación',
              icon: LucideIcons.qrCode,
              onPressed: () => context.push(AppRoutes.coachInviteCode),
            ),
            PrimaryButton(
              key: const Key('clients_reload'),
              label: 'Actualizar',
              icon: LucideIcons.refreshCw,
              variant: AppButtonVariant.ghost,
              onPressed: viewModel.load,
            ),
          ],
        );
      }
    }

    final visible = viewModel.visibleClients;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.md,
          ),
          child: _SearchField(onChanged: viewModel.search),
        ),
        if (viewModel.error case final message?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: ErrorBanner(message: message),
          ),
        Expanded(
          child: CardEdgeClip(
            child: RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.huge,
                ),
                children: [
                  if (viewModel.hasNoMatches)
                    const EmptyState(
                      icon: LucideIcons.userRoundSearch,
                      title: 'Sin resultados',
                      message: 'Ningún cliente coincide con la búsqueda.',
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        visible.length == 1
                            ? '1 cliente'
                            : '${visible.length} clientes',
                        style: context.text.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      child: SurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          children: [
                            for (final (index, client) in visible.indexed) ...[
                              if (index > 0)
                                const Divider(
                                  height: AppSpacing.xxs,
                                  indent: AppSpacing.dividerInset,
                                ),
                              _ClientRow(
                                client: client,
                                onTap: () async {
                                  await context.push(
                                    AppRoutes.coachClientDetail(client.id),
                                    extra: client,
                                  );
                                  // Al regresar se recarga por si cambió su meta.
                                  await viewModel.load();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Buscador en forma de píldora.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('clients_search'),
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.search),
        hintText: 'Buscar por nombre',
        fillColor: context.colors.surfaceContainerHigh,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(
            color: context.colors.onSurface,
            width: AppSizes.borderThick,
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client, required this.onTap});

  final ClientSummary client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final goal = client.goal;
    final lastMeal = lastMealText(client.lastMealAt, now: DateTime.now());
    return PressScale(
      child: InkWell(
        key: Key('client_${client.id}'),
        onTap: withHaptic(onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              AppAvatar(email: client.email, size: AppSizes.avatar),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(goalSummaryText(goal), style: text.bodyMedium),
                    Text(
                      goal == null
                          ? lastMeal
                          : '${goalSourceText(goal)} · $lastMeal',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
