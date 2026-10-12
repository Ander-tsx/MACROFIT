import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/password_field.dart';
import '../../domain/entities/role.dart';
import 'register_view_model.dart';

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu cuenta se creó, pero no pudimos iniciar sesión. Inicia sesión con tus datos.',
        ),
      ),
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegisterViewModel>();
    final colors = Theme.of(context).colorScheme;
    final roleError = viewModel.fieldError(RegisterViewModel.roleField);
    final privacyError = viewModel.fieldError(RegisterViewModel.privacyField);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (viewModel.generalError case final message?) ...[
                      ErrorBanner(message: message),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      key: const Key('register_name'),
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.setName,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        errorText: viewModel.fieldError(
                          RegisterViewModel.nameField,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('register_email'),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.setEmail,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        errorText: viewModel.fieldError(
                          RegisterViewModel.emailField,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      key: const Key('register_password'),
                      label: 'Contraseña (mínimo 8 caracteres)',
                      autofillHints: const [AutofillHints.newPassword],
                      errorText: viewModel.fieldError(
                        RegisterViewModel.passwordField,
                      ),
                      onChanged: viewModel.setPassword,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    Text(
                      '¿Cómo usarás MacroFit?',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<Role>(
                      key: const Key('register_role'),
                      emptySelectionAllowed: true,
                      selected: {?viewModel.role},
                      onSelectionChanged: (selection) => viewModel.setRole(
                        selection.isEmpty ? null : selection.first,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: Role.user,
                          label: Text('Usuario'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: Role.coach,
                          label: Text('Coach'),
                          icon: Icon(Icons.sports),
                        ),
                      ],
                    ),
                    if (roleError != null) _FieldErrorText(roleError),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      key: const Key('register_privacy'),
                      value: viewModel.privacyAccepted,
                      onChanged: (value) =>
                          viewModel.setPrivacyAccepted(value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      isError: privacyError != null,
                      title: const Text(
                        'He leído y acepto el aviso de privacidad',
                      ),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('register_privacy_link'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: colors.primary,
                          ),
                          onPressed: () =>
                              context.push(AppRoutes.privacyNotice),
                          child: const Text('Leer el aviso de privacidad'),
                        ),
                      ),
                    ),
                    if (privacyError != null) _FieldErrorText(privacyError),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('register_submit'),
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () => _submit(context, viewModel),
                      child: viewModel.isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensaje de error para controles que no son `TextField` (rol, aviso).
class _FieldErrorText extends StatelessWidget {
  const _FieldErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
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
