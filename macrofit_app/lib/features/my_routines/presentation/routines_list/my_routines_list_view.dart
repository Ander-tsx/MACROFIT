import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/icon_bubble.dart';
import '../../../../core/presentation/widgets/list_row.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../domain/entities/user_routine.dart';
import '../widgets/my_routine_texts.dart';
import '../widgets/origin_tag.dart';
import 'my_routines_list_view_model.dart';

/// HU-16 — «Mis rutinas» del usuario con su origen (RF-15, RN-08).
class MyRoutinesListView extends StatelessWidget {
  const MyRoutinesListView({super.key});

  Future<void> _openDetail(
    BuildContext context,
    MyRoutinesListViewModel viewModel,
    String id, {
    UserRoutineSummary? summary,
  }) async {
    await context.push(AppRoutes.myRoutineDetail(id), extra: summary);
    // Al regresar se recarga: la rutina pudo retirarse o cambiar (RF-23).
    await viewModel.load();
  }

  Future<void> _requestRecommended(
    BuildContext context,
    MyRoutinesListViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await viewModel.requestRecommended();
    if (!context.mounted) return;
    if (id == null) {
      if (viewModel.requestError case final message?) {
        showAppSnackBar(messenger, message, tone: StatusTone.error);
      }
      return;
    }
    await _openDetail(context, viewModel, id);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRoutinesListViewModel>();
    return Scaffold(
      appBar: const AppHeader(title: 'Mis rutinas'),
      body: SafeArea(
        child: CardEdgeClip(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: StateSwitcher(
              stateKey: _stateKey(viewModel),
              child: _body(context, viewModel),
            ),
          ),
        ),
      ),
    );
  }

  String _stateKey(MyRoutinesListViewModel viewModel) {
    if (viewModel.routines.isNotEmpty) return 'data';
    if (viewModel.isLoading) return 'loading';
    if (viewModel.error != null) return 'error';
    if (viewModel.hasNoRoutines) return 'empty';
    return 'loading';
  }

  Widget _body(BuildContext context, MyRoutinesListViewModel viewModel) {
    final routines = viewModel.routines;
    if (routines.isEmpty) {
      // Lista desplazable para que «deslizar hacia abajo» funcione en todos
      // los estados.
      final Widget content;
      if (viewModel.isLoading ||
          (!viewModel.hasNoRoutines && viewModel.error == null)) {
        content = const LoadingState(message: 'Cargando tus rutinas…');
      } else if (viewModel.error case final message?) {
        content = ErrorState(
          message: message,
          onRetry: viewModel.load,
          retryKey: const Key('my_routines_retry'),
        );
      } else {
        content = EmptyState(
          key: const Key('my_routines_empty'),
          icon: LucideIcons.dumbbell,
          title: 'Aún no tienes rutinas.',
          message:
              'Pide una rutina recomendada según tu objetivo, nivel y días '
              'de entrenamiento, o espera a que tu coach te asigne una.',
          actions: [
            PrimaryButton(
              key: const Key('my_routines_recommended'),
              label: 'Ver recomendada',
              icon: LucideIcons.sparkles,
              isLoading: viewModel.isRequesting,
              onPressed: viewModel.isRequesting
                  ? null
                  : () => _requestRecommended(context, viewModel),
            ),
          ],
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        children: [ContentWidth(child: content)],
      );
    }

    return ListView(
      key: const Key('my_routines_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.screenPadding,
      children: [
        if (viewModel.error case final message?) ...[
          ErrorBanner(key: const Key('my_routines_error'), message: message),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        for (final (index, routine) in routines.indexed) ...[
          FadeSlideIn(
            index: index,
            child: ContentWidth(
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: ListRow(
                  key: Key('my_routine_${routine.id}'),
                  leading: IconBubble(
                    icon: routine.origin == RoutineOrigin.system
                        ? LucideIcons.sparkles
                        : LucideIcons.dumbbell,
                  ),
                  title: routine.name,
                  subtitle: sessionCountText(routine.sessionCount),
                  footer: OriginTag(
                    origin: routine.origin,
                    coachName: routine.coachName,
                  ),
                  action: const Icon(LucideIcons.chevronRight),
                  onTap: () => _openDetail(
                    context,
                    viewModel,
                    routine.id,
                    summary: routine,
                  ),
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
