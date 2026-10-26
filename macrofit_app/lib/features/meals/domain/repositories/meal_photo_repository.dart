import '../entities/meal_photo.dart';

/// Foto de una comida (HU-06): obtenerla en el dispositivo y subirla.
abstract interface class MealPhotoRepository {
  /// Abre la cámara o la galería y devuelve la foto comprimida, o `null` si la
  /// persona canceló. Lanza `PhotoPickException` si falta el permiso o la cámara.
  Future<PickedPhoto?> pickPhoto(PhotoSource source);

  /// Android puede cerrar la app mientras la cámara está abierta. Al arrancar,
  /// esto recupera la foto que no llegó a [pickPhoto] y la guarda hasta que la
  /// tome [takeRecoveredPhoto]. Nunca lanza: si no hay foto, no hace nada.
  Future<void> recoverLostPhoto();

  /// Hay una foto recuperada esperando a la pantalla de la foto.
  bool get hasRecoveredPhoto;

  /// Entrega la foto recuperada una sola vez (después devuelve `null`).
  PickedPhoto? takeRecoveredPhoto();

  /// `POST /meals/photos` (multipart, campo `photo`). Lanza `ApiException`
  /// (p. ej. `PHOTO_TOO_LARGE`, `UNSUPPORTED_PHOTO_TYPE` o sin red).
  Future<UploadedPhoto> uploadPhoto(PickedPhoto photo);
}
