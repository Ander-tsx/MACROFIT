import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../data/models/coach_link_model.dart';
import '../../domain/repositories/coach_link_repository.dart';

/// HU-13 — vinculación con el coach mediante código de invitación.
class CoachLinkViewModel extends ViewModel {
  CoachLinkViewModel({required this._repository});

  final CoachLinkRepository _repository;

  String _inviteCode = '';
  bool _isLoading = false;
  String? _errorMessage;
  CoachLinkModel? _linkedCoach;

  String get inviteCode => _inviteCode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CoachLinkModel? get linkedCoach => _linkedCoach;

  void updateInviteCode(String value) {
    _inviteCode = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// Vincula al usuario con el coach usando el código ingresado.
  /// Se normaliza sin espacios y en mayúsculas (RF-12).
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
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.inviteCodeNotFound) {
        _errorMessage = 'Código inválido';
      } else if (error.code == ApiErrorCode.userAlreadyLinked) {
        _errorMessage = 'Ya tienes una vinculación activa con un coach. Primero debes desvincularte.';
      } else {
        _errorMessage = error.message;
      }
      notifyListeners();
      return false;
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
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
