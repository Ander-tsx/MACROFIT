import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/registration.dart';
import '../../domain/entities/role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';

/// Resultado de enviar el registro.
enum RegisterOutcome {
  /// Faltan datos o el backend los rechazó: los errores se muestran en el formulario.
  invalid,

  /// Cuenta creada y sesión iniciada: el router lleva a la pantalla principal.
  loggedIn,

  /// Cuenta creada, pero el inicio de sesión automático falló: hay que ir a login.
  createdWithoutSession,
}

/// HU-01 — registro con rol. Valida todo en la app antes de enviar y, si el
/// registro es exitoso, inicia sesión automáticamente con los mismos datos.
class RegisterViewModel extends ViewModel with FormStateMixin {
  RegisterViewModel(this._auth);

  final AuthRepository _auth;

  // Mismos nombres que la API para mostrar los errores del backend en su campo.
  static const nameField = 'name';
  static const emailField = 'email';
  static const passwordField = 'password';
  static const passwordConfirmationField = 'password_confirmation';
  static const roleField = 'role';
  static const privacyField = 'privacy_accepted';

  static const _apiFields = {
    nameField,
    emailField,
    passwordField,
    roleField,
    privacyField,
  };

  String _name = '';
  String _email = '';
  String _password = '';
  String _passwordConfirmation = '';
  Role? _role;
  bool _privacyAccepted = false;

  Role? get role => _role;
  bool get privacyAccepted => _privacyAccepted;

  void setName(String value) => _update(nameField, () => _name = value);

  void setEmail(String value) => _update(emailField, () => _email = value);

  void setPassword(String value) =>
      _update(passwordField, () => _password = value);

  void setPasswordConfirmation(String value) =>
      _update(passwordConfirmationField, () => _passwordConfirmation = value);

  void setRole(Role? value) => _update(roleField, () => _role = value);

  void setPrivacyAccepted(bool value) =>
      _update(privacyField, () => _privacyAccepted = value);

  Future<RegisterOutcome> submit() async {
    if (isSubmitting) return RegisterOutcome.invalid;

    final errors = <String, String?>{
      nameField: AuthValidators.name(_name),
      emailField: AuthValidators.email(_email),
      passwordField: AuthValidators.newPassword(_password),
      passwordConfirmationField: AuthValidators.passwordConfirmation(
        _password,
        _passwordConfirmation,
      ),
      roleField: AuthValidators.role(_role),
      privacyField: AuthValidators.privacyAccepted(_privacyAccepted),
    }..removeWhere((_, message) => message == null);
    setFieldErrors(errors.cast<String, String>());
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return RegisterOutcome.invalid;
    }

    final email = _email.trim();
    setSubmitting(true);
    try {
      await _auth.register(
        Registration(
          name: _name.trim(),
          email: email,
          password: _password,
          role: _role!,
          privacyAccepted: _privacyAccepted,
        ),
      );
    } on ApiException catch (error) {
      applyApiError(error, knownFields: _apiFields);
      setSubmitting(false);
      return RegisterOutcome.invalid;
    }

    try {
      await _auth.login(email: email, password: _password);
      return RegisterOutcome.loggedIn;
    } on ApiException {
      return RegisterOutcome.createdWithoutSession;
    } finally {
      setSubmitting(false);
    }
  }

  void _update(String field, void Function() change) {
    change();
    clearFieldError(field);
    notifyListeners();
  }
}
