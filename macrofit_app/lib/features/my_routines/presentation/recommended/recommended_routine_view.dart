import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
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
import '../../../../core/presentation/widgets/metric_tile.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../domain/entities/user_routine.dart';
import '../widgets/my_routine_texts.dart';
import '../widgets/session_plan_card.dart';
import 'recommended_routine_view_model.dart';

/// HU-15 — solicita la rutina recomendada y la muestra con sus sesiones (RF-14).
class RecommendedRoutineView extends StatelessWidget {
  const RecommendedRoutineView({super.key});

  Future<void> _generate(
    BuildContext context,
    RecommendedRoutineViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await viewModel.generate(
      () => showConfirmDialog(
        context: context,
        title: 'Generar de nuevo',
        message:
            'Tu rutina recomendada actual se reemplazará por una nueva. '
            'Tus sesiones completadas se conservan.',
        confirmLabel: 'Generar de nuevo',
        icon: LucideIcons.refreshCw,
        confirmKey: const Key('recommended_regenerate_confirm'),
        cancelKey: const Key('recommended_regenerate_cancel'),
      ),
    );
    if (result == GenerateRoutineResult.generated) {
      showAppSnackBar(messenger, 'Tu rutina recomendada está lista.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecommendedRoutineViewModel>();
    return Scaffold(
      appBar: const AppHeader(title: 'Rutina recomendada'),
      body: SafeArea(
        child: CardEdgeClip(
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [ContentWidth(child: _content(context, viewModel))],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, RecommendedRoutineViewModel viewModel) {
    final onGenerate = viewModel.isGenerating
        ? null
        : () => _generate(context, viewModel);

    if (viewModel.routine case final routine?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoutineSummaryCard(routine: routine),
          const SizedBox(height: AppSpacing.cardGap),
          ..._feedback(context, viewModel),
          for (final (index, session) in routine.sessions.indexed) ...[
            FadeSlideIn(
              index: index,
              child: SessionPlanCard(session: session),
            ),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          _regenerateButton(viewModel, onGenerate),
        ],
      );
    }

    if (viewModel.existing case final existing?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: ListRow(
              key: const Key('recommended_existing'),
              leading: const IconBubble(icon: LucideIcons.sparkles),
              title: existing.name,
              subtitle: sessionCountText(existing.sessionCount),
              action: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push(
                AppRoutes.myRoutineDetail(existing.id),
                extra: existing,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          ..._feedback(context, viewModel),
          _regenerateButton(viewModel, onGenerate),
        ],
      );
    }

    if (viewModel.loadError case final message?) {
      return ErrorState(
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('recommended_retry'),
      );
    }
    if (viewModel.isLoading) {
      return const LoadingState(message: 'Revisando tu rutina…');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._feedback(context, viewModel),
        EmptyState(
          key: const Key('recommended_empty'),
          icon: LucideIcons.sparkles,
          title: 'Tu rutina, a tu medida.',
          message:
              'La armamos según tu objetivo, tu nivel y tus días de '
              'entrenamiento.',
          actions: [
            PrimaryButton(
              key: const Key('recommended_generate'),
              label: viewModel.isGenerating
                  ? 'Generando tu rutina…'
                  : 'Generar mi rutina',
              icon: LucideIcons.sparkles,
              isLoading: viewModel.isGenerating,
              onPressed: onGenerate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _regenerateButton(
    RecommendedRoutineViewModel viewModel,
    VoidCallback? onGenerate,
  ) => PrimaryButton(
    key: const Key('recommended_regenerate'),
    label: viewModel.isGenerating ? 'Generando tu rutina…' : 'Generar de nuevo',
    icon: LucideIcons.refreshCw,
    variant: AppButtonVariant.tonal,
    isLoading: viewModel.isGenerating,
    onPressed: onGenerate,
  );

  /// Error de la última solicitud; sin perfil, lleva a completarlo.
  List<Widget> _feedback(
    BuildContext context,
    RecommendedRoutineViewModel viewModel,
  ) {
    final message = viewModel.generateError;
    if (message == null) return const [];
    return [
      if (viewModel.needsProfile) ...[
        StatusBanner(
          key: const Key('recommended_needs_profile'),
          message: message,
          tone: StatusTone.warning,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          key: const Key('recommended_complete_profile'),
          label: 'Completar perfil',
          icon: LucideIcons.chevronRight,
          variant: AppButtonVariant.tonal,
          compact: true,
          onPressed: () => context.push(AppRoutes.profileEdit),
        ),
      ] else
        ErrorBanner(key: const Key('recommended_error'), message: message),
      const SizedBox(height: AppSpacing.cardGap),
    ];
  }
}

/// Nombre de la rutina con el objetivo, el nivel y los días con que se generó.
class _RoutineSummaryCard extends StatelessWidget {
  const _RoutineSummaryCard({required this.routine});

  final RecommendedRoutine routine;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      key: const Key('recommended_summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(routine.name, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Objetivo',
                  value: routine.objective.label,
                ),
              ),
              Expanded(
                child: MetricTile(label: 'Nivel', value: routine.level.label),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Días',
                  value: '${routine.trainingDays}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
