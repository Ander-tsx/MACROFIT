import 'package:flutter/foundation.dart';

import '../errors/api_exception.dart';

/// Base de todos los ViewModels (MVVM).
///
/// - Expone estado inmutable desde fuera y lo cambia solo con sus métodos.
/// - No notifica después de `dispose`: una acción async puede terminar cuando la
///   pantalla ya se cerró (p. ej. el login exitoso dispara la navegación).
abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Estado común de un formulario: errores por campo y error general.
mixin FormStateMixin on ViewModel {
  Map<String, String> _fieldErrors = const {};
  String? _generalError;
  bool _isSubmitting = false;

  /// Error de un campo (clave = nombre del campo en la API).
  String? fieldError(String field) => _fieldErrors[field];

  Map<String, String> get fieldErrors => _fieldErrors;

  /// Error que no corresponde a un campo (credenciales, red, etc.).
  String? get generalError => _generalError;

  bool get isSubmitting => _isSubmitting;

  @protected
  void setFieldErrors(Map<String, String> errors) {
    _fieldErrors = Map.unmodifiable(errors);
  }

  @protected
  void setGeneralError(String? message) => _generalError = message;

  @protected
  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  /// Limpia el error de un campo cuando la persona lo edita.
  @protected
  void clearFieldError(String field) {
    if (_fieldErrors.containsKey(field) || _generalError != null) {
      _fieldErrors = Map.unmodifiable({..._fieldErrors}..remove(field));
      _generalError = null;
    }
  }

  /// Muestra un error de la API: los campos conocidos van junto a su campo;
  /// si ninguno aplica, el mensaje se muestra como error general.
  @protected
  void applyApiError(ApiException error, {required Set<String> knownFields}) {
    final known = {
      for (final entry in error.fields.entries)
        if (knownFields.contains(entry.key)) entry.key: entry.value,
    };
    _fieldErrors = Map.unmodifiable(known);
    _generalError = known.isEmpty ? error.message : null;
  }
}
