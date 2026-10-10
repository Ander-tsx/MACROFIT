import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/nutritional_goal.dart';
import '../../domain/validators/coach_goal_validators.dart';
import 'coach_goal_form_view_model.dart';

/// HU-05 — meta de un cliente vinculado: formulario e historial.
class CoachGoalFormView extends StatelessWidget {
  const CoachGoalFormView({super.key});

  Future<void> _submit(
    BuildContext context,
    CoachGoalFormViewModel viewModel,
  ) async {
    final saved = await viewModel.submit();
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Meta guardada')));
  }

  Future<void> _pickDate(
    BuildContext context,
    CoachGoalFormViewModel viewModel,
  ) async {
    final today = viewModel.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.effectiveFrom,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Vigente desde',
    );
    if (picked != null) viewModel.setEffectiveFrom(picked);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CoachGoalFormViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.client.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (viewModel.generalError case final message?) ...[
                  ErrorBanner(message: message),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('goal_calories'),
                  initialValue: viewModel.calories,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: viewModel.setCalories,
                  decoration: InputDecoration(
                    labelText: 'Calorías',
                    suffixText: 'kcal',
                    helperText: 'Entre 1 y ${CoachGoalValidators.caloriesMax}',
                    errorText: viewModel.fieldError(
                      CoachGoalFormViewModel.caloriesField,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('goal_protein'),
                  initialValue: viewModel.protein,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: viewModel.setProtein,
                  decoration: InputDecoration(
                    labelText: 'Proteína',
                    suffixText: 'g',
                    helperText: 'Entre 1 y ${CoachGoalValidators.macroMaxG}',
                    errorText: viewModel.fieldError(
                      CoachGoalFormViewModel.proteinField,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('goal_fat'),
                  initialValue: viewModel.fat,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onChanged: viewModel.setFat,
                  decoration: InputDecoration(
                    labelText: 'Grasa',
                    suffixText: 'g',
                    helperText: 'Entre 1 y ${CoachGoalValidators.macroMaxG}',
                    errorText: viewModel.fieldError(
                      CoachGoalFormViewModel.fatField,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const Key('goal_effective_from'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _pickDate(context, viewModel),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Vigente desde',
                      suffixIcon: const Icon(Icons.calendar_today),
                      errorText: viewModel.fieldError(
                        CoachGoalFormViewModel.effectiveFromField,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(viewModel.effectiveFrom)),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('goal_submit'),
                  onPressed: viewModel.isSubmitting
                      ? null
                      : () => _submit(context, viewModel),
                  child: viewModel.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar meta'),
                ),
                const SizedBox(height: 32),
                Text('Historial', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._history(viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _history(CoachGoalFormViewModel viewModel) {
    if (viewModel.isLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (viewModel.loadError case final message?) {
      return [
        ErrorBanner(message: message),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('goal_history_retry'),
          onPressed: viewModel.load,
          child: const Text('Reintentar'),
        ),
      ];
    }
    if (viewModel.history.isEmpty) {
      return const [Text('Este cliente todavía no tiene metas.')];
    }
    return [for (final goal in viewModel.history) _GoalTile(goal)];
  }

  /// `dd/mm/aaaa`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile(this.goal);

  final NutritionalGoal goal;

  @override
  Widget build(BuildContext context) {
    final date = goal.effectiveFrom.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        goal.source == GoalSource.coach ? Icons.sports : Icons.calculate,
      ),
      title: Text(
        '${goal.calories} kcal · P ${goal.proteinG} g · G ${goal.fatG} g',
      ),
      subtitle: Text(
        '${goal.source == GoalSource.coach ? 'Coach' : 'Calculada'} · '
        'desde ${CoachGoalFormView._formatDate(date)}',
      ),
    );
  }
}
