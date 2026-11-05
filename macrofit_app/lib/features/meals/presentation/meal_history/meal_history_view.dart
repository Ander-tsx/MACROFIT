import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/async_photo.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/day_total_card.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/meal_entry_card.dart';
import '../../../../core/presentation/widgets/period_navigator.dart';
import '../../../../core/presentation/widgets/press_scale.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../domain/entities/meal.dart';
import '../widgets/meal_texts.dart';
import 'meal_history_view_model.dart';

/// HU-09 — "Mis comidas": registros del día con hora, foto y valores, cambio de
/// día y eliminación con confirmación (RF-08).
class MealHistoryView extends StatelessWidget {
  const MealHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealHistoryViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Mis comidas'),
      floatingActionButton: PressScale(
        child: FloatingActionButton.extended(
          key: const Key('meal_history_add'),
          onPressed: withHaptic(() => context.push(AppRoutes.mealPhoto)),
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text('Registrar comida'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: PeriodNavigator(
                label: dayLabel(viewModel.date, now: viewModel.today),
                previousKey: const Key('meal_history_prev'),
                nextKey: const Key('meal_history_next'),
                labelKey: const Key('meal_history_date'),
                previousTooltip: 'Día anterior',
                nextTooltip: 'Día siguiente',
                onPrevious: viewModel.previousDay,
                onNext: viewModel.canGoForward ? viewModel.nextDay : null,
                onLabelTap: () => _pickDate(context, viewModel),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.normal,
                child: KeyedSubtree(
                  key: ValueKey(_stateOf(viewModel)),
                  child: _body(context, viewModel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateOf(MealHistoryViewModel viewModel) {
    if (viewModel.isLoading) return 'loading';
    if (viewModel.error != null) return 'error';
    if (viewModel.isEmptyDay) return 'empty';
    return 'list-${viewModel.date}';
  }

  Widget _body(BuildContext context, MealHistoryViewModel viewModel) {
    if (viewModel.isLoading) return const LoadingState();
    if (viewModel.error case final message?) {
      return ErrorState(
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('meal_history_retry'),
      );
    }
    if (viewModel.isEmptyDay) {
      return EmptyState(
        key: const Key('meal_history_empty'),
        icon: Icons.no_meals_outlined,
        title: 'No hay registros este día.',
        message: 'Registra una comida o revisa otro día.',
        actions: [
          PrimaryButton(
            key: const Key('meal_history_pick_date'),
            label: 'Elige otra fecha',
            icon: Icons.calendar_today_rounded,
            variant: AppButtonVariant.outlined,
            expand: false,
            onPressed: () => _pickDate(context, viewModel),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.bottomBarClearance,
        ),
        children: [
          if (viewModel.deleteError case final message?) ...[
            ErrorBanner(
              key: const Key('meal_history_delete_error'),
              message: message,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FadeSlideIn(
            child: DayTotalCard(
              key: const Key('meal_history_totals'),
              values: mealValuesText(viewModel.totals),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (index, meal) in viewModel.meals.indexed) ...[
            FadeSlideIn(
              index: index + 1,
              child: _MealCard(meal: meal, viewModel: viewModel),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  MealHistoryViewModel viewModel,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: viewModel.date,
    firstDate: DateTime(2020),
    lastDate: viewModel.today,
    helpText: 'Elige el día',
  );
  if (picked != null) unawaited(viewModel.selectDate(picked));
}

/// Pide confirmación, elimina y muestra el aviso que deje el ViewModel.
Future<void> _confirmDelete(
  BuildContext context,
  MealHistoryViewModel viewModel,
  Meal meal,
) async {
  final confirmed = await showConfirmDialog(
    context: context,
    title: '¿Eliminar este registro?',
    message:
        'Se eliminará la comida de las ${mealTimeText(meal.eatenAt)} '
        '(${mealValuesText(meal.values)})'
        '${meal.photoId == null ? '' : ' y su foto'}. No se puede deshacer.',
    confirmLabel: 'Eliminar',
    icon: Icons.delete_outline_rounded,
    destructive: true,
    confirmKey: const Key('meal_delete_confirm'),
    cancelKey: const Key('meal_delete_cancel'),
  );
  if (!confirmed || !context.mounted) return;
  // La tarjeta de [context] desaparece al eliminar o al recargar el día
  // (`MEAL_NOT_FOUND`): el aviso se muestra con el messenger de la pantalla.
  final messenger = ScaffoldMessenger.of(context);
  await viewModel.delete(meal);
  if (viewModel.takeNotice() case final notice?) {
    showAppSnackBar(messenger, notice);
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.viewModel});

  final Meal meal;
  final MealHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MealEntryCard(
      key: Key('meal_${meal.id}'),
      time: mealTimeText(meal.eatenAt),
      values: mealValuesText(meal.values),
      isManual: meal.photoId == null,
      photo: switch (meal.photoId) {
        final photoId? => AsyncPhoto(
          key: Key('meal_${meal.id}_photo'),
          photo: viewModel.photo(photoId),
        ),
        null => PhotoPlaceholder(key: Key('meal_${meal.id}_manual')),
      },
      trailing: IconButton(
        key: Key('meal_${meal.id}_delete'),
        tooltip: 'Eliminar registro',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: viewModel.deletingId == null
            ? () => _confirmDelete(context, viewModel, meal)
            : null,
      ),
    );
  }
}
