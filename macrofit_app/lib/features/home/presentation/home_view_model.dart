import '../../../core/presentation/view_model.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/domain/repositories/auth_repository.dart';

/// ViewModel compartido por las pantallas principales de usuario y coach.
class HomeViewModel extends ViewModel {
  HomeViewModel(this._auth) {
    _auth.addListener(notifyListeners);
  }

  final AuthRepository _auth;

  bool _isLoggingOut = false;

  User? get user => _auth.currentUser;
  bool get isLoggingOut => _isLoggingOut;

  /// HU-02 — cierra la sesión. El router lleva a login y reemplaza la pila,
  /// así que el botón atrás no regresa a esta pantalla.
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    notifyListeners();
    await _auth.logout();
  }

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }
}
