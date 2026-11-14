import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/icon_bubble.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/press_scale.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../../clients/domain/entities/client_summary.dart';
import '../widgets/routine_texts.dart';
import 'assign_routine_view_model.dart';

/// HU-19 — «Asignar rutina»: selección múltiple de clientes vinculados, los que
/// ya la tienen marcados y bloqueados, confirmación y aviso de éxito (CU-04 5–6).
class AssignRoutineView extends StatelessWidget {
  const AssignRoutineView({super.key});

  Future<void> _assign(
    BuildContext context,
    AssignRoutineViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final assigned = await viewModel.assign(
      (clients) => _confirmAssign(context, viewModel, clients),
    );
    if (!assigned || !context.mounted) return;
    showAppSnackBar(messenger, viewModel.successMessage);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AssignRoutineViewModel>();
    final showsSubmit = viewModel.clients.isNotEmpty;

    return Scaffold(
      appBar: const AppHeader(title: 'Asignar rutina'),
      body: SafeArea(bottom: !showsSubmit, child: _body(context, viewModel)),
      bottomNavigationBar: showsSubmit
          ? SafeArea(
              minimum: AppSpacing.screenPadding,
              child: PrimaryButton(
                key: const Key('assign_routine_submit'),
                label: viewModel.selectedCount == 0
                    ? 'Asignar'
                    : 'Asignar (${viewModel.selectedCount})',
                icon: LucideIcons.userCheck,
                isLoading: viewModel.isAssigning,
                onPressed: viewModel.canAssign
                    ? () => _assign(context, viewModel)
                    : null,
              ),
            )
          : null,
    );
  }

  Widget _body(BuildContext context, AssignRoutineViewModel viewModel) {
    if (viewModel.clients.isEmpty) {
      if (viewModel.isLoading) {
        return const LoadingState(message: 'Cargando tus clientes…');
      }
      if (viewModel.error case final message?) {
        return ErrorState(
          message: message,
          onRetry: viewModel.load,
          retryKey: const Key('assign_routine_retry'),
        );
      }
      if (viewModel.hasNoClients) {
        return EmptyState(
          key: const Key('assign_routine_no_clients'),
          icon: LucideIcons.userPlus,
          title: 'Todavía no tienes clientes vinculados.',
          message:
              'Para asignar «${viewModel.routine.name}» primero vincula a tus '
              'clientes: compárteles tu código de invitación. La rutina ya '
              'está guardada.',
          actions: [
            PrimaryButton(
              key: const Key('assign_routine_invite_code'),
              label: 'Ver mi código de invitación',
              icon: LucideIcons.qrCode,
              onPressed: () => context.push(AppRoutes.coachInviteCode),
            ),
            PrimaryButton(
              key: const Key('assign_routine_reload'),
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
          child: _RoutineCard(viewModel: viewModel),
        ),
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
            child: ErrorBanner(
              key: const Key('assign_routine_error'),
              message: message,
            ),
          )
        else if (viewModel.allAssigned)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: StatusBanner(
              key: Key('assign_routine_all_assigned'),
              message: 'Todos tus clientes ya tienen esta rutina.',
            ),
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
                  AppSpacing.xxl,
                ),
                children: [
                  if (viewModel.hasNoMatches)
                    const EmptyState(
                      icon: LucideIcons.userRoundSearch,
                      title: 'Sin resultados',
                      message: 'Ningún cliente coincide con la búsqueda.',
                    )
                  else
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
                              _ClientCheckRow(
                                client: client,
                                assigned: viewModel.isAssigned(client),
                                selected: viewModel.isSelected(client),
                                enabled: !viewModel.isAssigning,
                                onTap: () => viewModel.toggle(client),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resumen que se confirma antes de enviar: la rutina y los clientes elegidos.
Future<bool> _confirmAssign(
  BuildContext context,
  AssignRoutineViewModel viewModel,
  List<ClientSummary> clients,
) {
  final names = [for (final client in clients) '• ${client.name}'].join('\n');
  final count = clients.length == 1
      ? '1 cliente'
      : '${clients.length} clientes';
  return showConfirmDialog(
    context: context,
    title: 'Asignar rutina',
    message: '«${viewModel.routine.name}» se asignará a $count:\n\n$names',
    confirmLabel: 'Asignar',
    icon: LucideIcons.userCheck,
    confirmKey: const Key('assign_routine_confirm'),
    cancelKey: const Key('assign_routine_cancel'),
  );
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.viewModel});

  final AssignRoutineViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return SurfaceCard(
      child: Row(
        children: [
          IconBubble(
            icon: LucideIcons.dumbbell,
            color: colors.onSurface,
            background: colors.surfaceContainer,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.routine.name,
                  key: const Key('assign_routine_name'),
                  style: text.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  routineSummaryText(viewModel.routine),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Buscador en forma de píldora (mismo estilo que «Mis clientes»).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('assign_routine_search'),
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.search),
        hintText: 'Buscar cliente por nombre',
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

class _ClientCheckRow extends StatelessWidget {
  const _ClientCheckRow({
    required this.client,
    required this.assigned,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ClientSummary client;

  /// Ya tiene la rutina: se muestra marcado y no se puede tocar.
  final bool assigned;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final canTap = enabled && !assigned;
    final row = InkWell(
      key: Key('assign_client_${client.id}'),
      onTap: canTap ? withHaptic(onTap, selection: true) : null,
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
                  Text(
                    assigned ? 'Ya asignada' : client.email,
                    key: assigned
                        ? Key('assign_client_assigned_${client.id}')
                        : null,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              key: Key('assign_client_check_${client.id}'),
              value: assigned || selected,
              onChanged: canTap ? (_) => onTap() : null,
            ),
          ],
        ),
      ),
    );
    return canTap ? PressScale(child: row) : row;
  }
}
