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

  /// Vincula al usuario con el coach usando el código ingresado.
  /// Se normaliza (trim y mayúsculas) según RF-12.
  Future<bool> linkCoach() async {
    final trimmed = _inviteCode.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'El código de invitación es obligatorio.';
      notifyListeners();
      return false;
    }

    final normalizedCode = trimmed.toUpperCase();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _linkedCoach = await _repository.linkCoach(normalizedCode);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.inviteCodeNotFound) {
        _errorMessage = 'Código inválido';
      } else if (error.code == ApiErrorCode.userAlreadyLinked) {
        _errorMessage =
            'Ya tienes una vinculación activa con un coach. Primero debes desvincularte.';
      } else {
        _errorMessage = error.message;
      }
      _isLoading = false;
      notifyListeners();
      return false;
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
