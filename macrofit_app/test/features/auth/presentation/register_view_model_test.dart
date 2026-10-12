import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/domain/entities/role.dart';
import 'package:macrofit_app/features/auth/presentation/register/register_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late RegisterViewModel viewModel;

  setUp(() {
    auth = FakeAuthRepository();
    viewModel = RegisterViewModel(auth);
  });

  void fillValidForm({Role role = Role.coach}) {
    viewModel
      ..setName(' Ana ')
      ..setEmail('Ana@MacroFit.test')
      ..setPassword('Segura123')
      ..setPasswordConfirmation('Segura123')
      ..setRole(role)
      ..setPrivacyAccepted(true);
  }

  test('formulario vacío: no envía y señala cada problema', () async {
    final outcome = await viewModel.submit();

    expect(outcome, RegisterOutcome.invalid);
    expect(auth.registrations, isEmpty);
    expect(viewModel.fieldErrors.keys, {
      RegisterViewModel.nameField,
      RegisterViewModel.emailField,
      RegisterViewModel.passwordField,
      RegisterViewModel.passwordConfirmationField,
      RegisterViewModel.roleField,
      RegisterViewModel.privacyField,
    });
  });

  test('contraseñas distintas no permiten enviar', () async {
    fillValidForm();
    viewModel.setPasswordConfirmation('Segura124');

    await viewModel.submit();

    expect(auth.registrations, isEmpty);
    expect(
      viewModel.fieldError(RegisterViewModel.passwordConfirmationField),
      'Las contraseñas no coinciden',
    );
  });

  test('sin rol o sin aviso no permiten enviar', () async {
    fillValidForm();
    viewModel
      ..setRole(null)
      ..setPrivacyAccepted(false);

    await viewModel.submit();

    expect(auth.registrations, isEmpty);
    expect(
      viewModel.fieldError(RegisterViewModel.roleField),
      'Debes elegir un rol',
    );
    expect(
      viewModel.fieldError(RegisterViewModel.privacyField),
      'Debes aceptar el aviso de privacidad',
    );
  });

  test(
    'registro válido crea la cuenta e inicia sesión automáticamente',
    () async {
      fillValidForm();

      final outcome = await viewModel.submit();

      expect(outcome, RegisterOutcome.loggedIn);
      final registration = auth.registrations.single;
      expect(registration.name, 'Ana');
      expect(registration.role, Role.coach);
      expect(registration.privacyAccepted, isTrue);
      expect(auth.logins.single.password, 'Segura123');
      expect(auth.state, isA<Authenticated>());
    },
  );

  test('correo ya registrado se muestra en el campo de correo', () async {
    auth.registerError = apiError(
      ApiErrorCode.emailAlreadyExists,
      status: 409,
      fields: {'email': 'Este correo ya está registrado'},
    );
    fillValidForm();

    final outcome = await viewModel.submit();

    expect(outcome, RegisterOutcome.invalid);
    expect(
      viewModel.fieldError(RegisterViewModel.emailField),
      'Este correo ya está registrado',
    );
    expect(viewModel.generalError, isNull);
    expect(auth.logins, isEmpty);
  });

  test('error sin campos (sin red) se muestra como error general', () async {
    auth.registerError = networkError;
    fillValidForm();

    await viewModel.submit();

    expect(viewModel.generalError, networkError.message);
  });

  test(
    'si el login automático falla, avisa que la cuenta sí se creó',
    () async {
      auth.loginError = networkError;
      fillValidForm();

      final outcome = await viewModel.submit();

      expect(outcome, RegisterOutcome.createdWithoutSession);
      expect(auth.registrations, hasLength(1));
      expect(viewModel.isSubmitting, isFalse);
    },
  );
}
