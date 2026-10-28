/// Por qué no se pudo obtener una foto del dispositivo.
enum PhotoPickError {
  /// La persona negó (o tiene restringido) el permiso de cámara (CU-01 flujo 2a).
  cameraDenied,

  /// La persona negó (o tiene restringido) el acceso a sus fotos.
  galleryDenied,

  /// El dispositivo no tiene cámara disponible.
  cameraUnavailable,
}

/// Error al tomar o elegir una foto. Lo lanza `MealPhotoRepository.pickPhoto`.
class PhotoPickException implements Exception {
  const PhotoPickException(this.error);

  final PhotoPickError error;

  @override
  String toString() => 'PhotoPickException($error)';
}
