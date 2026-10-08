import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/presentation/login/login_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late LoginViewModel viewModel;

  setUp(() {
    auth = FakeAuthRepository();
    viewModel = LoginViewModel(auth);
  });

  test('sin datos no llama al backend y señala ambos campos', () async {
    await viewModel.submit();

    expect(auth.logins, isEmpty);
    expect(viewModel.fieldError(LoginViewModel.emailField), isNotNull);
    expect(viewModel.fieldError(LoginViewModel.passwordField), isNotNull);
  });

  test(
    'credenciales válidas inician sesión con el correo sin espacios',
    () async {
      viewModel
        ..setEmail('  ana@macrofit.test ')
        ..setPassword('Segura123');

      await viewModel.submit();

      expect(auth.logins.single.email, 'ana@macrofit.test');
      expect(auth.state, isA<Authenticated>());
      expect(viewModel.generalError, isNull);
      expect(viewModel.isSubmitting, isFalse);
    },
  );

  test('INVALID_CREDENTIALS se muestra como error general', () async {
    auth.loginError = apiError(
      ApiErrorCode.invalidCredentials,
      status: 401,
      message: 'Correo o contraseña incorrectos',
    );
    viewModel
      ..setEmail('ana@macrofit.test')
      ..setPassword('incorrecta');

    await viewModel.submit();

    expect(viewModel.generalError, 'Correo o contraseña incorrectos');
    expect(viewModel.fieldErrors, isEmpty);
  });

  test('editar un campo limpia su error y el error general', () async {
    auth.loginError = networkError;
    viewModel
      ..setEmail('ana@macrofit.test')
      ..setPassword('Segura123');
    await viewModel.submit();
    expect(viewModel.generalError, isNotNull);

    viewModel.setPassword('Segura1234');

    expect(viewModel.generalError, isNull);
  });
}
