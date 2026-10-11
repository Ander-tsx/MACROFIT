import '../entities/privacy_notice.dart';

/// Documentos legales. Lanza `ApiException` ante errores de la API o de red.
abstract interface class LegalRepository {
  /// Aviso de privacidad vigente; la fuente es `docs/legal/` servida por el backend.
  Future<PrivacyNotice> getPrivacyNotice();
}
