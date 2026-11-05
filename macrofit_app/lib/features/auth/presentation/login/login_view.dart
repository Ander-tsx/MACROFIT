import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/password_field.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../widgets/auth_layout.dart';
import 'login_view_model.dart';

/// HU-02 — pantalla de inicio de sesión.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final text = context.text;

    return Scaffold(
      body: AuthLayout(
        tagline: 'Registra tus comidas con una foto y alcanza tu meta.',
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bienvenido de nuevo', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Inicia sesión para continuar',
                style: text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (viewModel.generalError case final message?) ...[
                ErrorBanner(message: message),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                key: const Key('login_email'),
                label: 'Correo electrónico',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: viewModel.setEmail,
                errorText: viewModel.fieldError(LoginViewModel.emailField),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                key: const Key('login_password'),
                label: 'Contraseña',
                errorText: viewModel.fieldError(LoginViewModel.passwordField),
                onChanged: viewModel.setPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => viewModel.submit(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                key: const Key('login_submit'),
                label: 'Iniciar sesión',
                icon: Icons.arrow_forward_rounded,
                isLoading: viewModel.isSubmitting,
                onPressed: viewModel.submit,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '¿No tienes cuenta? Crea una',
                variant: AppButtonVariant.ghost,
                onPressed: viewModel.isSubmitting
                    ? null
                    : () => context.push(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
