import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';

/// HU-02 — inicio de sesión. Al tener éxito, el repositorio cambia a
/// `Authenticated` y el router lleva a la pantalla principal del rol.
class LoginViewModel extends ViewModel with FormStateMixin {
  LoginViewModel(this._auth);

  final AuthRepository _auth;

  static const emailField = 'email';
  static const passwordField = 'password';

  String _email = '';
  String _password = '';

  void setEmail(String value) {
    _email = value;
    clearFieldError(emailField);
    notifyListeners();
  }

  void setPassword(String value) {
    _password = value;
    clearFieldError(passwordField);
    notifyListeners();
  }

  Future<void> submit() async {
    if (isSubmitting) return;

    final errors = {
      emailField: AuthValidators.email(_email),
      passwordField: AuthValidators.loginPassword(_password),
    }..removeWhere((_, message) => message == null);
    setFieldErrors(errors.cast<String, String>());
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return;
    }

    setSubmitting(true);
    try {
      await _auth.login(email: _email.trim(), password: _password);
    } on ApiException catch (error) {
      applyApiError(error, knownFields: {emailField, passwordField});
    } finally {
      setSubmitting(false);
    }
  }
}
