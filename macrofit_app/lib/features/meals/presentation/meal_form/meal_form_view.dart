import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Comida registrada')));
    // TODO(HU-09-APP): ir al historial del día con el registro nuevo.
    context.go(AppRoutes.userHome);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealFormViewModel>();
    final photo = viewModel.draft.photo;

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isManual ? 'Captura manual' : 'Revisar valores'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photo.photo.bytes,
                      key: const Key('meal_form_photo'),
                      height: 140,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      semanticLabel: 'Foto de tu comida',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  viewModel.isManual
                      ? 'Captura las calorías, proteína y grasa de tu comida.'
                      : 'Revisa los valores estimados y corrígelos si hace falta.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (viewModel.generalError case final message?) ...[
                  ErrorBanner(
                    key: const Key('meal_form_error'),
                    message: message,
                  ),
                  const SizedBox(height: 16),
                ],
                _AmountField(
                  fieldKey: const Key('meal_form_calories_kcal'),
                  label: 'Calorías',
                  suffix: 'kcal',
                  helper: 'De 0 a 10 000',
                  initialValue: viewModel.calories,
                  error: viewModel.errorFor(MealFormViewModel.caloriesField),
                  onChanged: viewModel.setCalories,
                ),
                const SizedBox(height: 16),
                _AmountField(
                  fieldKey: const Key('meal_form_protein_g'),
                  label: 'Proteína',
                  suffix: 'g',
                  helper: 'De 0 a 1 000',
                  initialValue: viewModel.protein,
                  error: viewModel.errorFor(MealFormViewModel.proteinField),
                  onChanged: viewModel.setProtein,
                ),
                const SizedBox(height: 16),
                _AmountField(
                  fieldKey: const Key('meal_form_fat_g'),
                  label: 'Grasa',
                  suffix: 'g',
                  helper: 'De 0 a 1 000',
                  initialValue: viewModel.fat,
                  error: viewModel.errorFor(MealFormViewModel.fatField),
                  onChanged: viewModel.setFat,
                  last: true,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('meal_form_submit'),
                  onPressed: viewModel.isSubmitting
                      ? null
                      : () => _submit(context, viewModel),
                  child: viewModel.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.fieldKey,
    required this.label,
    required this.suffix,
    required this.helper,
    required this.initialValue,
    required this.error,
    required this.onChanged,
    this.last = false,
  });

  final Key fieldKey;
  final String label;
  final String suffix;
  final String helper;
  final String initialValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
