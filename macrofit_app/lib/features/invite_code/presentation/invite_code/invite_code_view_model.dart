import 'dart:ui' show Rect;

import '../../../../core/errors/api_exception.dart';
import '../../../../core/platform/share_service.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/invite_share_message.dart';
import '../../domain/repositories/invite_code_repository.dart';

/// HU-12 — código de invitación del coach: verlo, copiarlo, compartirlo y regenerarlo.
class InviteCodeViewModel extends ViewModel {
  InviteCodeViewModel({required this._repository, required this._shareService});

  final InviteCodeRepository _repository;
  final ShareService _shareService;

  String? _code;
  bool _isLoading = false;
  bool _isRegenerating = false;
  String? _loadError;
  String? _regenerateError;

  /// Código vigente; `null` mientras no se ha cargado.
  String? get code => _code;

  bool get isLoading => _isLoading;
  bool get isRegenerating => _isRegenerating;

  /// No se pudo obtener el código (p. ej. sin red). La vista ofrece reintentar.
  String? get loadError => _loadError;

  /// Falló la regeneración; el código anterior sigue visible y vigente.
  String? get regenerateError => _regenerateError;

  /// Copiar, compartir y regenerar solo con un código cargado y sin regenerar.
  bool get canUseCode => _code != null && !_isRegenerating;

  /// Carga (o reintenta cargar) el código con `GET /coach/invite-code`.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _code = await _repository.getInviteCode();
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pide confirmación con [confirm] (el código actual dejará de funcionar) y, si
  /// se acepta, genera uno nuevo. Si se cancela no se llama a la API.
  /// Devuelve `true` si el código cambió.
  Future<bool> regenerate(Future<bool> Function() confirm) async {
    if (!canUseCode) return false;
    if (!await confirm()) return false;
    _isRegenerating = true;
    _regenerateError = null;
    notifyListeners();
    try {
      _code = await _repository.regenerateInviteCode();
      return true;
    } on ApiException catch (error) {
      _regenerateError = error.message;
      return false;
    } finally {
      _isRegenerating = false;
      notifyListeners();
    }
  }

  /// Copia solo el código al portapapeles. Devuelve `true` si había código.
  Future<bool> copy() async {
    final code = _code;
    if (code == null) return false;
    await _shareService.copyText(code);
    return true;
  }

  /// Abre la hoja de compartir del sistema con el mensaje y el código.
  /// [origin] es el área del botón (ancla del popover en iPad).
  Future<void> share({Rect? origin}) async {
    final code = _code;
    if (code == null) return;
    await _shareService.shareText(
      inviteShareMessage(code),
      subject: inviteShareSubject,
      origin: origin,
    );
  }
}
