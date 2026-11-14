import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/async_photo.dart';
import '../../../../core/presentation/widgets/day_total_card.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/meal_entry_card.dart';
import '../../../../core/presentation/widgets/period_navigator.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/client_meal.dart';
import '../widgets/client_meal_texts.dart';
import 'client_meals_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-25 — registro diario de comidas de un cliente. Solo lectura (RN-07): no hay
/// opciones para crear, editar ni eliminar registros.
///
/// Si el cliente ya no está vinculado, **Volver a mis clientes** cierra esta pantalla
/// con `true` y el detalle también se cierra para regresar a la lista.
class ClientMealsView extends StatelessWidget {
  const ClientMealsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientMealsViewModel>();

    return Scaffold(
      appBar: AppHeader(title: 'Comidas de ${viewModel.client.name}'),
      body: SafeArea(
        child: viewModel.isUnlinked
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ErrorBanner(
                        message: 'Este cliente ya no está vinculado contigo.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        key: const Key('client_meals_back'),
                        label: 'Volver a mis clientes',
                        icon: LucideIcons.arrowLeft,
                        onPressed: () => context.pop(true),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      AppSpacing.md,
                    ),
                    child: PeriodNavigator(
                      label: dayLabel(viewModel.date, now: viewModel.today),
                      previousKey: const Key('client_meals_prev'),
                      nextKey: const Key('client_meals_next'),
                      labelKey: const Key('client_meals_date'),
                      previousTooltip: 'Día anterior',
                      nextTooltip: 'Día siguiente',
                      onPrevious: viewModel.previousDay,
                      onNext: viewModel.canGoForward ? viewModel.nextDay : null,
                      onLabelTap: () => _pickDate(context, viewModel),
                    ),
                  ),
                  Expanded(
                    child: CardEdgeClip(child: _body(context, viewModel)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _body(BuildContext context, ClientMealsViewModel viewModel) {
    if (viewModel.isLoading) return const LoadingState();
    if (viewModel.error case final message?) {
      return ErrorState(
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('client_meals_retry'),
      );
    }
    if (viewModel.isEmptyDay) {
      return EmptyState(
        icon: LucideIcons.utensilsCrossed,
        title: 'No hay registros este día.',
        message: 'Tu cliente no registró comidas en esta fecha.',
        actions: [
          PrimaryButton(
            key: const Key('client_meals_pick_date'),
            label: 'Elige otra fecha',
            icon: LucideIcons.calendar,
            variant: AppButtonVariant.outlined,
            expand: false,
            onPressed: () => _pickDate(context, viewModel),
          ),
        ],
      );
    }
    final totals = viewModel.totals;
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.huge,
        ),
        children: [
          FadeSlideIn(
            child: DayTotalCard(
              key: const Key('client_meals_totals'),
              values: mealValuesText(
                calories: totals.calories,
                proteinG: totals.proteinG,
                fatG: totals.fatG,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          FadeSlideIn(
            index: 1,
            child: SectionCard(
              title: 'Registros',
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  for (final (index, meal) in viewModel.meals.indexed) ...[
                    if (index > 0) const Divider(height: AppSpacing.lg),
                    _MealRow(meal: meal, viewModel: viewModel),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  ClientMealsViewModel viewModel,
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

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.viewModel});

  final ClientMeal meal;
  final ClientMealsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MealEntryCard(
      time: mealTimeText(meal.eatenAt),
      values: mealValuesText(
        calories: meal.caloriesKcal,
        proteinG: meal.proteinG,
        fatG: meal.fatG,
      ),
      isManual: meal.photoUrl == null,
      photo: switch (meal.photoUrl) {
        final url? => AsyncPhoto(
          key: Key('meal_${meal.id}_photo'),
          photo: viewModel.photo(url),
        ),
        null => PhotoPlaceholder(key: Key('meal_${meal.id}_manual')),
      },
    );
  }
}
