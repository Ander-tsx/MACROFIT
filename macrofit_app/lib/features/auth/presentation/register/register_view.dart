import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/field_error_text.dart';
import '../../../../core/presentation/widgets/password_field.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../domain/entities/role.dart';
import '../widgets/role_option.dart';
import 'register_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';

/// HU-01 — pantalla de registro con elección de rol y aviso de privacidad.
class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  Future<void> _submit(
    BuildContext context,
    RegisterViewModel viewModel,
  ) async {
    final outcome = await viewModel.submit();
    if (outcome != RegisterOutcome.createdWithoutSession || !context.mounted) {
      return;
    }

    showAppSnackBar(
      ScaffoldMessenger.of(context),
      'Tu cuenta se creó, pero no pudimos iniciar sesión. Inicia sesión con tus datos.',
      tone: StatusTone.info,
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegisterViewModel>();
    final roleError = viewModel.fieldError(RegisterViewModel.roleField);
    final privacyError = viewModel.fieldError(RegisterViewModel.privacyField);

    return Scaffold(
      appBar: const AppHeader(title: 'Crear cuenta'),
      body: SafeArea(
        // Desplazamiento simple (no una lista perezosa): el formulario completo
        // existe siempre y llevar un campo a la vista no requiere reconstruir.
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: ContentWidth(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tu cuenta te acompaña en cada comida y cada rutina.',
                    style: context.text.bodyLarge?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (viewModel.generalError case final message?) ...[
                    ErrorBanner(message: message),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SectionCard(
                    title: 'Tus datos',
                    icon: LucideIcons.idCard,
                    child: Column(
                      children: [
                        AppTextField(
                          key: const Key('register_name'),
                          label: 'Nombre',
                          icon: LucideIcons.user,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          onChanged: viewModel.setName,
                          errorText: viewModel.fieldError(
                            RegisterViewModel.nameField,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          key: const Key('register_email'),
                          label: 'Correo electrónico',
                          icon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onChanged: viewModel.setEmail,
                          errorText: viewModel.fieldError(
                            RegisterViewModel.emailField,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PasswordField(
                          key: const Key('register_password'),
                          label: 'Contraseña (mínimo 8 caracteres)',
                          autofillHints: const [AutofillHints.newPassword],
                          errorText: viewModel.fieldError(
                            RegisterViewModel.passwordField,
                          ),
                          onChanged: viewModel.setPassword,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PasswordField(
                          key: const Key('register_password_confirmation'),
                          label: 'Confirmar contraseña',
                          autofillHints: const [AutofillHints.newPassword],
                          errorText: viewModel.fieldError(
                            RegisterViewModel.passwordConfirmationField,
                          ),
                          onChanged: viewModel.setPasswordConfirmation,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionCard(
                    title: '¿Cómo usarás MacroFit?',
                    icon: LucideIcons.users,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            key: const Key('register_role'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: RoleOption(
                                  icon: LucideIcons.user,
                                  label: 'Usuario',
                                  description:
                                      'Registro mis comidas y sigo mi meta.',
                                  selected: viewModel.role == Role.user,
                                  hasError: roleError != null,
                                  onTap: () => viewModel.setRole(
                                    viewModel.role == Role.user
                                        ? null
                                        : Role.user,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: RoleOption(
                                  icon: LucideIcons.whistle,
                                  label: 'Coach',
                                  description:
                                      'Acompaño a mis clientes y sus metas.',
                                  selected: viewModel.role == Role.coach,
                                  hasError: roleError != null,
                                  onTap: () => viewModel.setRole(
                                    viewModel.role == Role.coach
                                        ? null
                                        : Role.coach,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FieldErrorText(roleError),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PrivacyConsent(
                    accepted: viewModel.privacyAccepted,
                    hasError: privacyError != null,
                    onChanged: viewModel.setPrivacyAccepted,
                  ),
                  FieldErrorText(privacyError),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    key: const Key('register_submit'),
                    label: 'Crear cuenta',
                    icon: LucideIcons.arrowRight,
                    isLoading: viewModel.isSubmitting,
                    onPressed: () => _submit(context, viewModel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Casilla del aviso de privacidad con el enlace para leerlo completo.
class _PrivacyConsent extends StatelessWidget {
  const _PrivacyConsent({
    required this.accepted,
    required this.hasError,
    required this.onChanged,
  });

  final bool accepted;
  final bool hasError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: BorderSide(
          color: hasError ? colors.error : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('register_privacy'),
        onTap: () => onChanged(!accepted),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: accepted,
                isError: hasError,
                onChanged: (value) => onChanged(value ?? false),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'He leído y acepto el aviso de privacidad',
                        style: context.text.bodyLarge,
                      ),
                      TextButton.icon(
                        key: const Key('register_privacy_link'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: colors.secondary,
                        ),
                        onPressed: () => context.push(AppRoutes.privacyNotice),
                        icon: const Icon(LucideIcons.fileText),
                        label: const Text('Leer el aviso de privacidad'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
