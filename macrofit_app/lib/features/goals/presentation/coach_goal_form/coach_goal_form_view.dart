import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/macro_style.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/date_field.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/nutritional_goal.dart';
import '../../domain/validators/coach_goal_validators.dart';
import 'coach_goal_form_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';

/// HU-05 — meta de un cliente vinculado: formulario e historial.
class CoachGoalFormView extends StatelessWidget {
  const CoachGoalFormView({super.key});

  Future<void> _submit(
    BuildContext context,
    CoachGoalFormViewModel viewModel,
  ) async {
    final saved = await viewModel.submit();
    if (!saved || !context.mounted) return;
    showAppSnackBar(ScaffoldMessenger.of(context), 'Meta guardada');
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

    return Scaffold(
      appBar: AppHeader(title: viewModel.client.name),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.huge,
          ),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  child: SectionCard(
                    title: 'Nueva meta diaria',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (viewModel.generalError case final message?) ...[
                          ErrorBanner(message: message),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _GoalField(
                          fieldKey: const Key('goal_calories'),
                          macro: Macro.calories,
                          suffix: 'kcal',
                          helper:
                              'Entre 1 y ${CoachGoalValidators.caloriesMax}',
                          initialValue: viewModel.calories,
                          error: viewModel.fieldError(
                            CoachGoalFormViewModel.caloriesField,
                          ),
                          onChanged: viewModel.setCalories,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _GoalField(
                          fieldKey: const Key('goal_protein'),
                          macro: Macro.protein,
                          suffix: 'g',
                          helper: 'Entre 1 y ${CoachGoalValidators.macroMaxG}',
                          initialValue: viewModel.protein,
                          error: viewModel.fieldError(
                            CoachGoalFormViewModel.proteinField,
                          ),
                          onChanged: viewModel.setProtein,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _GoalField(
                          fieldKey: const Key('goal_fat'),
                          macro: Macro.fat,
                          suffix: 'g',
                          helper: 'Entre 1 y ${CoachGoalValidators.macroMaxG}',
                          initialValue: viewModel.fat,
                          error: viewModel.fieldError(
                            CoachGoalFormViewModel.fatField,
                          ),
                          onChanged: viewModel.setFat,
                          last: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DateField(
                          key: const Key('goal_effective_from'),
                          label: 'Vigente desde',
                          value: _formatDate(viewModel.effectiveFrom),
                          errorText: viewModel.fieldError(
                            CoachGoalFormViewModel.effectiveFromField,
                          ),
                          onTap: () => _pickDate(context, viewModel),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          key: const Key('goal_submit'),
                          label: 'Guardar meta',
                          icon: LucideIcons.check,
                          isLoading: viewModel.isSubmitting,
                          onPressed: () => _submit(context, viewModel),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                FadeSlideIn(
                  index: 1,
                  child: SectionCard(
                    title: 'Historial',
                    child: StateSwitcher(
                      stateKey: viewModel.isLoading
                          ? 'loading'
                          : viewModel.loadError != null
                          ? 'error'
                          : viewModel.history.isEmpty
                          ? 'empty'
                          : 'data-${viewModel.history.length}',
                      child: _history(viewModel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _history(CoachGoalFormViewModel viewModel) {
    if (viewModel.isLoading) return const LoadingState(compact: true);
    if (viewModel.loadError case final message?) {
      return ErrorState(
        compact: true,
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('goal_history_retry'),
      );
    }
    if (viewModel.history.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: LucideIcons.history,
        title: 'Sin metas todavía',
        message: 'Este cliente todavía no tiene metas.',
      );
    }
    return Column(
      children: [
        for (final (index, goal) in viewModel.history.indexed)
          _GoalTimelineRow(goal: goal, isFirst: index == 0),
      ],
    );
  }

  /// `dd/mm/aaaa`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
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
  Widget build(BuildContext context) => AppTextField(
    key: fieldKey,
    label: macro.label,
    icon: macro.icon,
    initialValue: initialValue,
    keyboardType: TextInputType.number,
    textInputAction: last ? TextInputAction.done : TextInputAction.next,
    onChanged: onChanged,
    suffixText: suffix,
    helperText: helper,
    errorText: error,
  );
}

/// Meta del historial como punto de una línea de tiempo; la primera es la vigente.
class _GoalTimelineRow extends StatelessWidget {
  const _GoalTimelineRow({required this.goal, required this.isFirst});

  final NutritionalGoal goal;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final app = context.appColors;
    final date = goal.effectiveFrom.toLocal();
    final isCoach = goal.source == GoalSource.coach;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: AppSpacing.md,
                height: AppSpacing.md,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? app.calories : colors.outline,
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  width: AppSpacing.md,
                  color: colors.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goal.calories} kcal · P ${goal.proteinG} g · G ${goal.fatG} g',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(
                        isCoach ? LucideIcons.whistle : LucideIcons.sparkles,
                        size: AppSizes.iconXs,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${isCoach ? 'Coach' : 'Calculada'} · '
                        'desde ${CoachGoalFormView._formatDate(date)}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
