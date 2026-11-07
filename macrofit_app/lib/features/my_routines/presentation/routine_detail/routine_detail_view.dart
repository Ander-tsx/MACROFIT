import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../domain/entities/user_routine.dart';
import '../widgets/my_routine_texts.dart';
import '../widgets/origin_tag.dart';
import 'routine_detail_view_model.dart';

/// HU-16 — detalle de una rutina del usuario: cada sesión con sus ejercicios,
/// series, repeticiones y descanso (RF-15).
/// HU-17 — cada sesión se marca como completada con confirmación (RF-16).
class RoutineDetailView extends StatelessWidget {
  const RoutineDetailView({super.key});

  /// Mensaje cuando la rutina ya no está disponible (`ROUTINE_NOT_FOUND`).
  static const unavailableMessage =
      'Esta rutina ya no está disponible. Revisa tu lista de rutinas.';

  /// Mensaje de `SESSION_ALREADY_COMPLETED`.
  static const alreadyCompletedMessage = 'Ya registraste esta sesión hoy.';

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineDetailViewModel>();

    if (viewModel.takeUnavailable()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showAppSnackBar(
          ScaffoldMessenger.of(context),
          unavailableMessage,
          tone: StatusTone.warning,
        );
        if (context.canPop()) context.pop();
      });
    }

    return Scaffold(
      appBar: AppHeader(title: viewModel.title),
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

  Future<void> _complete(
    BuildContext context,
    RoutineDetailViewModel viewModel,
    RoutineSessionPlan session,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await viewModel.complete(
      session.number,
      () => showConfirmDialog(
        context: context,
        title: 'Marcar como completada',
        message: '¿Terminaste «${session.name}» hoy?',
        confirmLabel: 'Sí, completada',
        icon: LucideIcons.circleCheck,
        confirmKey: const Key('complete_session_confirm'),
        cancelKey: const Key('complete_session_cancel'),
      ),
    );
    switch (result) {
      case CompleteSessionResult.completed:
        showAppSnackBar(messenger, 'Sesión registrada. ¡Bien hecho!');
      case CompleteSessionResult.alreadyCompleted:
        showAppSnackBar(
          messenger,
          alreadyCompletedMessage,
          tone: StatusTone.info,
        );
      case CompleteSessionResult.failed:
        // El mensaje queda en la sesión con «Reintentar».
        break;
      case CompleteSessionResult.unavailable:
      case CompleteSessionResult.cancelled:
        // `unavailable` lo resuelve `takeUnavailable` en el siguiente build.
        break;
    }
  }

  Widget _content(BuildContext context, RoutineDetailViewModel viewModel) {
    final routine = viewModel.routine;
    if (routine == null) {
      if (viewModel.error case final message?) {
        return ErrorState(
          message: message,
          onRetry: viewModel.load,
          retryKey: const Key('routine_detail_retry'),
        );
      }
      if (viewModel.isUnavailable) {
        return const StatusBanner(
          message: unavailableMessage,
          tone: StatusTone.warning,
        );
      }
      return const LoadingState(message: 'Cargando la rutina…');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OriginTag(
            key: const Key('routine_detail_origin'),
            origin: routine.origin,
            coachName: routine.coachName,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (viewModel.sessionsError case final message?) ...[
          ErrorBanner(
            key: const Key('routine_sessions_error'),
            message: 'No pudimos consultar tus sesiones completadas. $message',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final (index, session) in routine.sessions.indexed) ...[
          FadeSlideIn(
            index: index,
            child: _SessionCard(
              session: session,
              footer: _SessionStatus(
                session: session,
                viewModel: viewModel,
                onComplete: () => _complete(context, viewModel, session),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.footer});

  final RoutineSessionPlan session;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return SectionCard(
      key: Key('routine_session_${session.number}'),
      title: session.name,
      subtitle: session.exercises.length == 1
          ? '1 ejercicio'
          : '${session.exercises.length} ejercicios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, exercise) in session.exercises.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.xxl),
            Text(exercise.name, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${muscleGroupText(exercise.muscleGroup)} · '
              '${exerciseVolumeText(exercise)}',
              style: text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          footer,
        ],
      ),
    );
  }
}

/// HU-17 — «Completada hoy · fecha» o el botón para marcarla.
class _SessionStatus extends StatelessWidget {
  const _SessionStatus({
    required this.session,
    required this.viewModel,
    required this.onComplete,
  });

  final RoutineSessionPlan session;
  final RoutineDetailViewModel viewModel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final number = session.number;
    if (viewModel.completedToday(number) case final done?) {
      return StatusBanner(
        key: Key('session_completed_$number'),
        message: completedTodayText(done.date),
        tone: StatusTone.success,
        icon: LucideIcons.circleCheck,
      );
    }
    final failed =
        viewModel.completeError != null && viewModel.lastFailedNumber == number;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed) ...[
          ErrorBanner(
            key: Key('complete_session_error_$number'),
            message: viewModel.completeError!,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PrimaryButton(
          key: Key('complete_session_$number'),
          label: failed ? 'Reintentar' : 'Marcar completada',
          icon: failed ? LucideIcons.refreshCw : LucideIcons.circleCheck,
          variant: AppButtonVariant.tonal,
          compact: true,
          isLoading: viewModel.isCompleting(number),
          onPressed: viewModel.isCompletingAny ? null : onComplete,
        ),
      ],
    );
  }
}
