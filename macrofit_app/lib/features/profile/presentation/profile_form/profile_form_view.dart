import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/choice_pills.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/date_field.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/field_error_text.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/profile.dart';
import '../../domain/validators/profile_validators.dart';
import 'profile_form_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

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
    showAppSnackBar(ScaffoldMessenger.of(context), 'Perfil actualizado');
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
      appBar: AppHeader(
        title: viewModel.isEditing ? 'Mi perfil' : 'Tu perfil inicial',
        actions: [
          if (!viewModel.isEditing)
            IconButton(
              key: const Key('profile_logout'),
              tooltip: 'Cerrar sesión',
              icon: viewModel.isLoggingOut
                  ? const InlineSpinner()
                  : const Icon(LucideIcons.logOut),
              onPressed: viewModel.isLoggingOut ? null : viewModel.logout,
            ),
        ],
      ),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, ProfileFormViewModel viewModel) {
    if (viewModel.isLoading) return const LoadingState();
    if (viewModel.loadError case final message?) {
      return ErrorState(
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('profile_retry'),
      );
    }

    return CardEdgeClip(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(child: _ProfileHero(viewModel: viewModel)),
              const SizedBox(height: AppSpacing.xl),
              if (viewModel.generalError case final message?) ...[
                FadeSlideIn(child: ErrorBanner(message: message)),
                const SizedBox(height: AppSpacing.md),
              ],
              FadeSlideIn(
                child: SectionCard(
                  title: 'Tu objetivo',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Label('Objetivo'),
                      ChoicePills<Objective>(
                        key: const Key('profile_objective'),
                        options: Objective.values,
                        selected: viewModel.objective,
                        labelOf: (objective) => objective.label,
                        hasError: _hasError(
                          viewModel,
                          ProfileFormViewModel.objectiveField,
                        ),
                        onChanged: viewModel.setObjective,
                      ),
                      FieldErrorText(
                        viewModel.fieldError(
                          ProfileFormViewModel.objectiveField,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _Label('Nivel'),
                      ChoicePills<ExperienceLevel>(
                        key: const Key('profile_level'),

                        options: ExperienceLevel.values,
                        selected: viewModel.level,
                        labelOf: (level) => level.label,
                        hasError: _hasError(
                          viewModel,
                          ProfileFormViewModel.levelField,
                        ),
                        onChanged: viewModel.setLevel,
                      ),
                      FieldErrorText(
                        viewModel.fieldError(ProfileFormViewModel.levelField),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _Label('Días de entrenamiento por semana'),
                      ChoicePills<int>(
                        options: [
                          for (
                            var days = ProfileValidators.trainingDaysMin;
                            days <= ProfileValidators.trainingDaysMax;
                            days++
                          )
                            days,
                        ],
                        selected: viewModel.trainingDays,
                        labelOf: (days) => '$days',
                        keyOf: (days) => Key('profile_training_days_$days'),
                        expand: true,
                        circular: true,
                        hasError: _hasError(
                          viewModel,
                          ProfileFormViewModel.trainingDaysField,
                        ),
                        onChanged: viewModel.setTrainingDays,
                      ),
                      FieldErrorText(
                        viewModel.fieldError(
                          ProfileFormViewModel.trainingDaysField,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              FadeSlideIn(
                index: 1,
                child: SectionCard(
                  title: 'Sobre ti',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        key: const Key('profile_weight'),
                        label: 'Peso',
                        icon: LucideIcons.weight,
                        initialValue: viewModel.weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: viewModel.setWeight,
                        suffixText: 'kg',
                        helperText:
                            'Entre ${ProfileValidators.weightMinKg} y ${ProfileValidators.weightMaxKg} kg',
                        errorText: viewModel.fieldError(
                          ProfileFormViewModel.weightField,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        key: const Key('profile_height'),
                        label: 'Estatura',
                        icon: LucideIcons.ruler,
                        initialValue: viewModel.height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: viewModel.setHeight,
                        suffixText: 'cm',
                        helperText:
                            'Entre ${ProfileValidators.heightMinCm} y ${ProfileValidators.heightMaxCm} cm',
                        errorText: viewModel.fieldError(
                          ProfileFormViewModel.heightField,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DateField(
                        key: const Key('profile_birth_date'),
                        label: 'Fecha de nacimiento',
                        value: switch (viewModel.birthDate) {
                          final date? => _formatDate(date),
                          null => null,
                        },
                        errorText: viewModel.fieldError(
                          ProfileFormViewModel.birthDateField,
                        ),
                        onTap: () => _pickBirthDate(context, viewModel),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _Label('Sexo'),
                      ChoicePills<Gender>(
                        key: const Key('profile_gender'),
                        expand: true,
                        options: Gender.values,
                        selected: viewModel.gender,
                        labelOf: (gender) => gender.label,
                        hasError: _hasError(
                          viewModel,
                          ProfileFormViewModel.genderField,
                        ),
                        onChanged: viewModel.setGender,
                      ),
                      FieldErrorText(
                        viewModel.fieldError(ProfileFormViewModel.genderField),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                key: const Key('profile_submit'),
                label: viewModel.isEditing
                    ? 'Guardar cambios'
                    : 'Guardar y continuar',
                icon: LucideIcons.check,
                isLoading: viewModel.isSubmitting,
                onPressed: () => _submit(context, viewModel),
              ),
              if (viewModel.isEditing) ...[
                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideIn(
                  index: 2,
                  child: _AccountCard(viewModel: viewModel),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasError(ProfileFormViewModel viewModel, String field) =>
      viewModel.fieldError(field) != null;

  /// `dd/mm/aaaa`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

/// Etiqueta de un grupo de opciones dentro de una tarjeta.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: context.text.labelLarge?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

/// **Cerrar sesión** al final de "Mi perfil" (los datos de la cuenta están arriba).
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.viewModel});

  final ProfileFormViewModel viewModel;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este dispositivo?',
      confirmLabel: 'Cerrar sesión',
      icon: LucideIcons.logOut,
      destructive: true,
      confirmKey: const Key('logout_confirm'),
    );
    if (confirmed) await viewModel.logout();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      key: const Key('logout_button'),
      label: 'Cerrar sesión',
      icon: LucideIcons.logOut,
      variant: AppButtonVariant.outlined,
      isLoading: viewModel.isLoggingOut,
      onPressed: () => _confirmLogout(context),
    );
  }
}

/// Encabezado del perfil: el blobatar del correo en grande, el nombre, el correo
/// y un resumen de los datos (se actualiza al editar los campos).
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.viewModel});

  final ProfileFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final app = context.appColors;
    final objective = viewModel.objective;
    final chips = <String>[
      ?objective?.label,
      if (viewModel.weight.trim().isNotEmpty) '${viewModel.weight.trim()} kg',
      if (viewModel.height.trim().isNotEmpty) '${viewModel.height.trim()} cm',
      if (viewModel.trainingDays case final days?) '$days días/sem',
    ];

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // Halo suave con los colores de los macros detrás del avatar.
        Container(
          width: AppSizes.profileHalo,
          height: AppSizes.profileHalo,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                app.protein.withValues(alpha: AppOpacity.track),
                app.calories.withValues(alpha: AppOpacity.glass / 2),
                colors.surface.withValues(alpha: 0),
              ],
            ),
          ),
          child: AppAvatar(
            email: viewModel.email,
            size: AppSizes.profileAvatar,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          viewModel.isEditing ? viewModel.name : 'Hola, ${viewModel.name}',
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          viewModel.email,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (!viewModel.isEditing) ...[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              'Cuéntanos sobre ti para calcular tu meta y recomendarte rutinas.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final chip in chips)
                AnimatedSwitcher(
                  duration: AppDurations.normal,
                  child: Container(
                    key: ValueKey(chip),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(chip, style: text.labelLarge),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
