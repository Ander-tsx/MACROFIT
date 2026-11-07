import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/icon_bubble.dart';
import '../../../../core/presentation/widgets/list_row.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../domain/entities/routine_assignment.dart';
import '../widgets/routine_texts.dart';
import 'routine_assignments_view_model.dart';

/// HU-20 — clientes con la rutina asignada; cada uno se puede retirar con
/// confirmación (RF-24). Sus sesiones completadas se conservan.
class RoutineAssignmentsView extends StatelessWidget {
  const RoutineAssignmentsView({super.key});

  Future<void> _remove(
    BuildContext context,
    RoutineAssignmentsViewModel viewModel,
    RoutineAssignment assignment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await viewModel.remove(
      assignment,
      () => showConfirmDialog(
        context: context,
        title: 'Retirar rutina',
        message:
            '¿Retirar «${viewModel.routine.name}» de ${assignment.clientName}? '
            'Dejará de verla en su app; sus sesiones completadas se conservan.',
        confirmLabel: 'Retirar',
        icon: LucideIcons.unlink,
        destructive: true,
        confirmKey: const Key('remove_assignment_confirm'),
        cancelKey: const Key('remove_assignment_cancel'),
      ),
    );
    switch (result) {
      case RemoveAssignmentResult.removed:
        showAppSnackBar(
          messenger,
          'Rutina retirada de ${assignment.clientName}',
        );
      case RemoveAssignmentResult.alreadyRemoved:
        showAppSnackBar(
          messenger,
          'La rutina ya se había retirado de ${assignment.clientName}',
          tone: StatusTone.info,
        );
      case RemoveAssignmentResult.failed:
      case RemoveAssignmentResult.cancelled:
        // El error queda en pantalla; cancelar no hace nada.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineAssignmentsViewModel>();
    return Scaffold(
      appBar: AppHeader(title: viewModel.routine.name),
      body: SafeArea(
        child: CardEdgeClip(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              children: [ContentWidth(child: _content(context, viewModel))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, RoutineAssignmentsViewModel viewModel) {
    final text = context.text;
    final assignments = viewModel.assignments;
    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        'Clientes asignados · ${routineSummaryText(viewModel.routine)}',
        style: text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );

    if (assignments.isEmpty) {
      final Widget body;
      if (viewModel.isLoading ||
          (!viewModel.hasNoAssignments && viewModel.error == null)) {
        body = const LoadingState(message: 'Cargando clientes asignados…');
      } else if (viewModel.error case final message?) {
        body = ErrorState(
          message: message,
          onRetry: viewModel.load,
          retryKey: const Key('routine_assignments_retry'),
        );
      } else {
        body = const EmptyState(
          key: Key('routine_assignments_empty'),
          icon: LucideIcons.users,
          title: 'Nadie tiene esta rutina.',
          message: 'Asígnala desde el menú de la rutina en «Mis rutinas».',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, body],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (viewModel.removeError case final message?) ...[
          ErrorBanner(
            key: const Key('remove_assignment_error'),
            message: message,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (viewModel.error case final message?) ...[
          ErrorBanner(message: message),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final (index, assignment) in assignments.indexed) ...[
          FadeSlideIn(
            index: index,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: ListRow(
                key: Key('assignment_${assignment.clientId}'),
                leading: const IconBubble(icon: LucideIcons.userRound),
                title: assignment.clientName,
                subtitle:
                    'Asignada el ${assignedDateText(assignment.assignedAt)}',
                action: viewModel.isRemovingClient(assignment.clientId)
                    ? const SizedBox.square(
                        dimension: AppSizes.spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: AppSizes.spinnerStroke,
                        ),
                      )
                    : IconButton(
                        key: Key('remove_assignment_${assignment.clientId}'),
                        tooltip: 'Retirar rutina',
                        icon: const Icon(LucideIcons.unlink),
                        color: context.colors.error,
                        onPressed: viewModel.isRemoving
                            ? null
                            : () => _remove(context, viewModel, assignment),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
      ],
    );
  }
}
