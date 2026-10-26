import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Acciones del sistema para sacar texto de la app: portapapeles y hoja de compartir.
///
/// Es un contrato para que los ViewModels se prueben sin plugins (`FakeShareService`
/// en las pruebas). La implementación real es [SystemShareService].
abstract interface class ShareService {
  /// Copia [text] al portapapeles.
  Future<void> copyText(String text);

  /// Abre la hoja de compartir del sistema con [text]. [subject] se usa como asunto
  /// cuando la app elegida lo admite (correo). [origin] es el área del botón que la
  /// abrió: en iPad ancla el popover ahí.
  Future<void> shareText(String text, {String? subject, Rect? origin});
}

/// [ShareService] con `Clipboard` de Flutter y `share_plus`.
class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
  }
}
