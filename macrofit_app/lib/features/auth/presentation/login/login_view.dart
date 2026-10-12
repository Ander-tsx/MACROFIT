import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/password_field.dart';
import 'login_view_model.dart';

/// HU-02 — pantalla de inicio de sesión.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
                    Icon(
                      Icons.fitness_center,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'MacroFit',
                      style: textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inicia sesión para continuar',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (viewModel.generalError case final message?) ...[
                      ErrorBanner(message: message),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      key: const Key('login_email'),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.setEmail,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        errorText: viewModel.fieldError(
                          LoginViewModel.emailField,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      key: const Key('login_password'),
                      label: 'Contraseña',
                      errorText: viewModel.fieldError(
                        LoginViewModel.passwordField,
                      ),
                      onChanged: viewModel.setPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => viewModel.submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login_submit'),
                      onPressed: viewModel.isSubmitting
                          ? null
                          : viewModel.submit,
                      child: viewModel.isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () => context.push(AppRoutes.register),
                      child: const Text('¿No tienes cuenta? Crea una'),
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
