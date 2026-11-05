import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../widgets/meal_navigation.dart';
import 'meal_form_view_model.dart';

/// HU-08 — "Revisar valores" (precargado con la estimación) o "Captura manual"
/// (vacío): calorías, proteína y grasa editables y **Guardar**.
class MealFormView extends StatelessWidget {
  const MealFormView({super.key});

  Future<void> _submit(
    BuildContext context,
    MealFormViewModel viewModel,
  ) async {
    final saved = await viewModel.submit();
    if (!saved || !context.mounted) return;
    showMealSaved(context, viewModel.saved!);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealFormViewModel>();
    final photo = viewModel.draft.photo;

    return Scaffold(
      appBar: AppHeader(
        title: viewModel.isManual ? 'Captura manual' : 'Revisar valores',
      ),
      body: SafeArea(
        // Todo el contenido se construye de una vez (pantalla corta): los
        // botones existen aunque estén fuera de la vista.
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photo != null) ...[
                      ClipRRect(
                        borderRadius: AppRadius.xlAll,
                        child: Image.memory(
                          photo.photo.bytes,
                          key: const Key('meal_form_photo'),
                          height: AppSizes.photoBanner,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          semanticLabel: 'Foto de tu comida',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    Text(
                      viewModel.isManual
                          ? 'Captura las calorías, proteína y grasa de tu comida.'
                          : 'Revisa los valores estimados y corrígelos si hace falta.',
                      style: context.text.bodyLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (viewModel.generalError case final message?) ...[
                      FadeSlideIn(
                        child: ErrorBanner(
                          key: const Key('meal_form_error'),
                          message: message,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    FadeSlideIn(
                      child: SectionCard(
                        title: 'Valores nutricionales',
                        child: Column(
                          children: [
                            _AmountField(
                              fieldKey: const Key('meal_form_calories_kcal'),
                              macro: Macro.calories,
                              suffix: 'kcal',
                              helper: 'De 0 a 10 000',
                              initialValue: viewModel.calories,
                              error: viewModel.errorFor(
                                MealFormViewModel.caloriesField,
                              ),
                              onChanged: viewModel.setCalories,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _AmountField(
                              fieldKey: const Key('meal_form_protein_g'),
                              macro: Macro.protein,
                              suffix: 'g',
                              helper: 'De 0 a 1 000',
                              initialValue: viewModel.protein,
                              error: viewModel.errorFor(
                                MealFormViewModel.proteinField,
                              ),
                              onChanged: viewModel.setProtein,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _AmountField(
                              fieldKey: const Key('meal_form_fat_g'),
                              macro: Macro.fat,
                              suffix: 'g',
                              helper: 'De 0 a 1 000',
                              initialValue: viewModel.fat,
                              error: viewModel.errorFor(
                                MealFormViewModel.fatField,
                              ),
                              onChanged: viewModel.setFat,
                              last: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    PrimaryButton(
                      key: const Key('meal_form_submit'),
                      label: 'Guardar',
                      icon: Icons.check_rounded,
                      isLoading: viewModel.isSubmitting,
                      onPressed: () => _submit(context, viewModel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.fieldKey,
    required this.macro,
    required this.suffix,
    required this.helper,
    required this.initialValue,
    required this.error,
    required this.onChanged,
    this.last = false,
  });

  final Key fieldKey;
  final Macro macro;
  final String suffix;
  final String helper;
  final String initialValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      key: fieldKey,
      label: macro.label,
      icon: macro.icon,
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onChanged: onChanged,
      suffixText: suffix,
      helperText: helper,
      errorText: error,
    );
  }
}
