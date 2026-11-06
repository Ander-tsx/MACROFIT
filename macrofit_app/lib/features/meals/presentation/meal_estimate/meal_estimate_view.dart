import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../../../core/presentation/widgets/stat_tile.dart';
import '../widgets/meal_navigation.dart';
import '../widgets/meal_texts.dart';
import 'meal_estimate_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-07 — "Estimación": carga, alimentos identificados y totales, o las
/// opciones ante un error (reintentar o capturar a mano).
class MealEstimateView extends StatelessWidget {
  const MealEstimateView({super.key});

  /// HU-08: "Corregir valores" abre el formulario precargado con la estimación
  /// y "Capturar a mano" lo abre vacío (con la foto ya subida).
  void _openForm(BuildContext context, MealEstimateViewModel viewModel) {
    unawaited(context.push(AppRoutes.mealForm, extra: viewModel.formDraft));
  }

  /// HU-09: guarda lo estimado sin corregir y abre el historial del día.
  Future<void> _save(
    BuildContext context,
    MealEstimateViewModel viewModel,
  ) async {
    final saved = await viewModel.save();
    if (!saved || !context.mounted) return;
    showMealSaved(context, viewModel.saved!);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealEstimateViewModel>();
    final estimate = viewModel.estimate;

    return Scaffold(
      appBar: const AppHeader(title: 'Estimación'),
      body: SafeArea(
        // Todo el contenido se construye de una vez (pantalla corta): los
        // botones existen aunque estén fuera de la vista.
        child: CardEdgeClip(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.xlAll,
                  child: Image.memory(
                    viewModel.upload.photo.bytes,
                    key: const Key('meal_estimate_photo'),
                    height: AppSizes.photoHeader,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: 'Foto de tu comida',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (viewModel.isLoading)
                  const LoadingState(
                    key: Key('meal_estimate_loading'),
                    message: 'Estimando calorías, proteína y grasa…',
                  )
                else if (estimate != null) ...[
                  FadeSlideIn(child: _Totals(estimate: estimate)),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(index: 1, child: _Foods(estimate: estimate)),
                  const SizedBox(height: AppSpacing.md),
                  const FadeSlideIn(
                    index: 2,
                    child: StatusBanner(
                      key: Key('meal_estimate_disclaimer'),
                      message: MealEstimateViewModel.disclaimer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (viewModel.saveError case final message?) ...[
                    ErrorBanner(
                      key: const Key('meal_estimate_save_error'),
                      message: message,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  PrimaryButton(
                    key: const Key('meal_estimate_save'),
                    label: 'Guardar',
                    icon: LucideIcons.check,
                    isLoading: viewModel.isSaving,
                    onPressed: () => _save(context, viewModel),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    key: const Key('meal_estimate_correct'),
                    label: 'Corregir valores',
                    icon: LucideIcons.slidersHorizontal,
                    variant: AppButtonVariant.outlined,
                    onPressed: viewModel.isSaving
                        ? null
                        : () => _openForm(context, viewModel),
                  ),
                ] else if (viewModel.error case final message?) ...[
                  FadeSlideIn(
                    child: ErrorBanner(
                      key: const Key('meal_estimate_error'),
                      message: message,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (viewModel.canRetry) ...[
                    PrimaryButton(
                      key: const Key('meal_estimate_retry'),
                      label: 'Reintentar',
                      icon: LucideIcons.refreshCw,
                      onPressed: viewModel.retry,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  PrimaryButton(
                    key: const Key('meal_estimate_manual'),
                    label: 'Capturar a mano',
                    icon: LucideIcons.notebookPen,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _openForm(context, viewModel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Totales en mosaicos (referencia: "Nutrition info"). El pie de proteína y
/// grasa indica cuánto aportan a la energía de la comida.
class _Totals extends StatelessWidget {
  const _Totals({required this.estimate});

  final MealEstimate estimate;

  /// Energía por gramo (Atwater) para saber cuánto aporta cada macro.
  static const _proteinKcalPerGram = 4;
  static const _fatKcalPerGram = 9;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final totals = estimate.totals;
    final kcal = totals.caloriesKcal;
    String share(double grams, int kcalPerGram) => kcal <= 0
        ? '—'
        : '${(grams * kcalPerGram / kcal * 100).round()} % energía';

    return SectionCard(
      title: 'Valores nutricionales',
      child: Row(
        key: const Key('meal_estimate_totals'),
        children: [
          Expanded(
            child: StatTile(
              label: Macro.calories.label,
              color: Macro.calories.color(app),
              value: formatAmount(kcal),
              unit: 'kcal',
              footer: 'total',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              label: Macro.protein.label,
              color: Macro.protein.color(app),
              value: formatAmount(totals.proteinG),
              unit: 'g',
              footer: share(totals.proteinG, _proteinKcalPerGram),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              label: Macro.fat.label,
              color: Macro.fat.color(app),
              value: formatAmount(totals.fatG),
              unit: 'g',
              footer: share(totals.fatG, _fatKcalPerGram),
            ),
          ),
        ],
      ),
    );
  }
}

class _Foods extends StatelessWidget {
  const _Foods({required this.estimate});

  final MealEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return SectionCard(
      title: 'Alimentos identificados',
      child: Column(
        children: [
          for (final (index, food) in estimate.foods.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.xxl),
            Row(
              key: Key('meal_estimate_food_$index'),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name, style: text.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(mealValuesText(food.values), style: text.bodySmall),
                    ],
                  ),
                ),
                if (food.grams case final grams?) ...[
                  const SizedBox(width: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '${formatAmount(grams)} g',
                        style: text.labelLarge,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
