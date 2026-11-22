import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/coach_link.dart';
import '../../domain/repositories/coach_link_repository.dart';

/// HU-13 / HU-14 — vinculación y desvinculación con el coach mediante código.
class CoachLinkViewModel extends ViewModel {
  CoachLinkViewModel({required this._repository});

  final CoachLinkRepository _repository;

  String _inviteCode = '';
  bool _isLoading = false;
  String? _errorMessage;
  CoachLink? _linkedCoach;

  String get inviteCode => _inviteCode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CoachLink? get linkedCoach => _linkedCoach;

  void updateInviteCode(String value) {
    _inviteCode = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// Carga el estado de vinculación guardado en el dispositivo.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _linkedCoach = await _repository.getLinkedCoach();
    } on Object {
      _linkedCoach = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Código sin espacios y en mayúsculas (RF-12), o `null` con el error si está vacío.
  String? _normalizedCode() {
    final trimmed = _inviteCode.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'El código de invitación es obligatorio.';
      notifyListeners();
      return null;
    }
    return trimmed.toUpperCase();
  }

  /// CU-02 paso 4 — nombre del coach del código para que el usuario confirme
  /// antes de vincularse; `null` si el código no sirve (el motivo queda en
  /// [errorMessage]). No vincula.
  Future<String?> previewCoach() async {
    final code = _normalizedCode();
    if (code == null) return null;
    return _call(() => _repository.previewCoach(code));
  }

  /// CU-02 pasos 5 y 6 — vincula al usuario con el coach del código ingresado.
  Future<bool> linkCoach() async {
    final code = _normalizedCode();
    if (code == null) return false;
    final link = await _call(() => _repository.linkCoach(code));
    if (link == null) return false;
    _linkedCoach = link;
    notifyListeners();
    return true;
  }

  /// Ejecuta [action] con el estado de carga y traduce los errores del código.
  Future<T?> _call<T>(Future<T> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (error) {
      _errorMessage = switch (error.code) {
        ApiErrorCode.inviteCodeNotFound => 'Código inválido',
        ApiErrorCode.userAlreadyLinked => 'Ya tienes una vinculación activa con un coach. Primero debes desvincularte.',
        _ => error.message,
      };
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// HU-14 — desvincula al usuario de su coach activo.
  Future<bool> unlinkCoach() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.unlinkCoach();
      _linkedCoach = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.userNotLinked) {
        _linkedCoach = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = error.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
