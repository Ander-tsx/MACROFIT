import 'dart:typed_data';

/// Reglas de TEC-13 para la foto de una comida. Son las mismas que
/// `backend/src/services/photos.rs` (`MAX_PHOTO_BYTES`, `detect_format`):
/// si cambias una, cambia la otra.
abstract final class MealPhotoValidator {
  /// Tamaño máximo: 5 MiB.
  static const maxBytes = 5 * 1024 * 1024;

  static const _jpegSignature = [0xFF, 0xD8, 0xFF];
  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  static const tooLargeMessage =
      'La foto pesa más de 5 MB. Elige otra o vuelve a tomarla.';
  static const unsupportedTypeMessage =
      'La foto debe ser JPEG o PNG. Elige otra o vuelve a tomarla.';
  static const emptyMessage = 'La foto está vacía. Elige otra.';

  /// Mensaje de error, o `null` si la foto se puede subir.
  /// Como el backend, revisa el tamaño antes que el tipo.
  static String? validate(Uint8List bytes) {
    if (bytes.isEmpty) return emptyMessage;
    if (bytes.length > maxBytes) return tooLargeMessage;
    if (!_startsWith(bytes, _jpegSignature) &&
        !_startsWith(bytes, _pngSignature)) {
      return unsupportedTypeMessage;
    }
    return null;
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }
}
