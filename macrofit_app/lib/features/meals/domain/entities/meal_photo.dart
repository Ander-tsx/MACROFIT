import 'dart:typed_data';

/// De dónde sale la foto de la comida (RF-05).
enum PhotoSource { camera, gallery }

/// Foto elegida en el dispositivo, ya comprimida, lista para subir.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;

  /// Nombre del archivo en el dispositivo; solo informativo (el backend revisa el contenido).
  final String fileName;

  int get sizeBytes => bytes.length;
}

/// Foto guardada en el backend (`POST /meals/photos`). HU-07 y HU-09 usan su [id].
class UploadedPhoto {
  const UploadedPhoto({
    required this.id,
    required this.format,
    required this.sizeBytes,
  });

  final String id;

  /// `jpeg` o `png`, según el contenido.
  final String format;
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      other is UploadedPhoto &&
      other.id == id &&
      other.format == format &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(id, format, sizeBytes);
}

/// Foto ya subida junto con sus bytes, para mostrarla en los pasos siguientes
/// (estimación de HU-07) sin volver a descargarla.
class MealPhotoUpload {
  const MealPhotoUpload({required this.photo, required this.uploaded});

  final PickedPhoto photo;
  final UploadedPhoto uploaded;

  String get photoId => uploaded.id;
}
