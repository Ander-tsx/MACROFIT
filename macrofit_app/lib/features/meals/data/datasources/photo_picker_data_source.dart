import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/meal_photo.dart';
import '../../domain/entities/photo_pick_exception.dart';

/// Cámara y galería del dispositivo con `image_picker`.
///
/// `image_picker` pide el permiso de cámara o de fotos cuando hace falta y, si
/// se niega, responde con un `PlatformException`; aquí se traduce a
/// [PhotoPickException] para que el dominio no dependa del paquete.
class PhotoPickerDataSource {
  PhotoPickerDataSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Lado mayor de la foto. Con [_imageQuality] la foto se vuelve a codificar
  /// (JPEG, o PNG si tiene transparencia) y queda muy por debajo de 5 MiB.
  static const maxDimension = 1600.0;
  static const _imageQuality = 85;

  static const _cameraDeniedCodes = {
    'camera_access_denied',
    'camera_access_restricted',
  };
  static const _galleryDeniedCodes = {
    'photo_access_denied',
    'photo_access_restricted',
  };

  /// La foto comprimida, o `null` si la persona canceló.
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: _imageQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw PhotoPickException(_errorFor(error.code, source));
    }
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), fileName: file.name);
  }

  /// Foto de una captura que la app no recibió porque Android la cerró con la
  /// cámara abierta (`retrieveLostData`), o `null`. Otras plataformas no la
  /// implementan; cualquier fallo se trata como "no hay foto".
  Future<PickedPhoto?> retrieveLost() async {
    try {
      final response = await _picker.retrieveLostData();
      final file = response.files?.firstOrNull ?? response.file;
      if (response.isEmpty || file == null) return null;
      return PickedPhoto(bytes: await file.readAsBytes(), fileName: file.name);
    } on PlatformException {
      return null;
    } on UnimplementedError {
      return null;
    }
  }

  PhotoPickError _errorFor(String code, PhotoSource source) {
    if (_cameraDeniedCodes.contains(code)) return PhotoPickError.cameraDenied;
    if (_galleryDeniedCodes.contains(code)) return PhotoPickError.galleryDenied;
    if (code == 'no_available_camera') return PhotoPickError.cameraUnavailable;
    // Cualquier otro fallo del sistema se trata como falta de acceso al origen.
    return source == PhotoSource.camera
        ? PhotoPickError.cameraUnavailable
        : PhotoPickError.galleryDenied;
  }
}
