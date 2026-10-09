import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/profile.dart';
import '../../domain/validators/profile_validators.dart';
import 'profile_form_view_model.dart';

/// HU-03 — perfil inicial (alta obligatoria tras el primer inicio de sesión) y edición ("Mi perfil").
class ProfileFormView extends StatelessWidget {
  const ProfileFormView({super.key});

  Future<void> _submit(
    BuildContext context,
    ProfileFormViewModel viewModel,
  ) async {
    final saved = await viewModel.submit();
    // En el alta el router cambia de pantalla solo; en la edición se regresa.
    if (!saved || !viewModel.isEditing || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    if (context.canPop()) context.pop();
  }

  Future<void> _pickBirthDate(
    BuildContext context,
    ProfileFormViewModel viewModel,
  ) async {
    final today = viewModel.today;
    final firstDate = DateTime(today.year - ProfileValidators.ageMaxYears - 1);
    final lastDate = DateTime(today.year, today.month, today.day);
    var initialDate = viewModel.birthDate ?? DateTime(today.year - 25);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) viewModel.setBirthDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Mi perfil' : 'Tu perfil inicial'),
        actions: [
          if (!viewModel.isEditing)
            IconButton(
              key: const Key('profile_logout'),
              tooltip: 'Cerrar sesión',
              icon: viewModel.isLoggingOut
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              onPressed: viewModel.isLoggingOut ? null : viewModel.logout,
            ),
        ],
      ),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, ProfileFormViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.loadError case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: message),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('profile_retry'),
                onPressed: viewModel.load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!viewModel.isEditing) ...[
                Text(
                  'Cuéntanos sobre ti para calcular tu meta y recomendarte rutinas.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
              ],
              if (viewModel.generalError case final message?) ...[
                ErrorBanner(message: message),
                const SizedBox(height: 16),
              ],
              const _SectionTitle('Objetivo'),
              SegmentedButton<Objective>(
                key: const Key('profile_objective'),
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                selected: {?viewModel.objective},
                onSelectionChanged: (selection) => viewModel.setObjective(
                  selection.isEmpty ? null : selection.first,
                ),
                segments: [
                  for (final objective in Objective.values)
                    ButtonSegment(
                      value: objective,
                      label: Text(objective.label, textAlign: TextAlign.center),
                    ),
                ],
              ),
              _FieldErrorText(
                viewModel.fieldError(ProfileFormViewModel.objectiveField),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Nivel'),
              SegmentedButton<ExperienceLevel>(
                key: const Key('profile_level'),
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                selected: {?viewModel.level},
                onSelectionChanged: (selection) => viewModel.setLevel(
                  selection.isEmpty ? null : selection.first,
                ),
                segments: [
                  for (final level in ExperienceLevel.values)
                    ButtonSegment(
                      value: level,
                      label: Text(level.label, textAlign: TextAlign.center),
                    ),
                ],
              ),
              _FieldErrorText(
                viewModel.fieldError(ProfileFormViewModel.levelField),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Días de entrenamiento por semana'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var days = ProfileValidators.trainingDaysMin;
                    days <= ProfileValidators.trainingDaysMax;
                    days++
                  )
                    ChoiceChip(
                      key: Key('profile_training_days_$days'),
                      label: Text('$days'),
                      selected: viewModel.trainingDays == days,
                      onSelected: (selected) =>
                          viewModel.setTrainingDays(selected ? days : null),
                    ),
                ],
              ),
              _FieldErrorText(
                viewModel.fieldError(ProfileFormViewModel.trainingDaysField),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('profile_weight'),
                initialValue: viewModel.weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onChanged: viewModel.setWeight,
                decoration: InputDecoration(
                  labelText: 'Peso',
                  suffixText: 'kg',
                  helperText:
                      'Entre ${ProfileValidators.weightMinKg} y ${ProfileValidators.weightMaxKg} kg',
                  errorText: viewModel.fieldError(
                    ProfileFormViewModel.weightField,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('profile_height'),
                initialValue: viewModel.height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onChanged: viewModel.setHeight,
                decoration: InputDecoration(
                  labelText: 'Estatura',
                  suffixText: 'cm',
                  helperText:
                      'Entre ${ProfileValidators.heightMinCm} y ${ProfileValidators.heightMaxCm} cm',
                  errorText: viewModel.fieldError(
                    ProfileFormViewModel.heightField,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Sexo'),
              SegmentedButton<Gender>(
                key: const Key('profile_gender'),
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                selected: {?viewModel.gender},
                onSelectionChanged: (selection) => viewModel.setGender(
                  selection.isEmpty ? null : selection.first,
                ),
                segments: [
                  for (final gender in Gender.values)
                    ButtonSegment(value: gender, label: Text(gender.label)),
                ],
              ),
              _FieldErrorText(
                viewModel.fieldError(ProfileFormViewModel.genderField),
              ),
              const SizedBox(height: 20),
              InkWell(
                key: const Key('profile_birth_date'),
                borderRadius: BorderRadius.circular(4),
                onTap: () => _pickBirthDate(context, viewModel),
                child: InputDecorator(
                  isEmpty: viewModel.birthDate == null,
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    suffixIcon: const Icon(Icons.calendar_today),
                    errorText: viewModel.fieldError(
                      ProfileFormViewModel.birthDateField,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    switch (viewModel.birthDate) {
                      final date? => _formatDate(date),
                      null => '',
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('profile_submit'),
                onPressed: viewModel.isSubmitting
                    ? null
                    : () => _submit(context, viewModel),
                child: viewModel.isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        viewModel.isEditing
                            ? 'Guardar cambios'
                            : 'Guardar y continuar',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `dd/mm/aaaa`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Mensaje de error para controles que no son `TextField`.
class _FieldErrorText extends StatelessWidget {
  const _FieldErrorText(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
