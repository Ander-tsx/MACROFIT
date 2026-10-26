import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/meal_photo.dart';
import '../../domain/entities/photo_pick_exception.dart';
import '../../domain/repositories/meal_photo_repository.dart';
import '../../domain/validators/meal_photo_validator.dart';

/// HU-06 — tomar o elegir la foto de la comida, verla y subirla.
class MealPhotoViewModel extends ViewModel {
  MealPhotoViewModel(this._repository);

  final MealPhotoRepository _repository;

  static const cameraDeniedMessage =
      'MacroFit no tiene permiso para usar la cámara. Para habilitarlo, abre '
      'los Ajustes del teléfono, busca MacroFit y permite la cámara. Mientras tanto, puedes elegir una foto de la galería.';
  static const galleryDeniedMessage =
      'MacroFit no tiene permiso para ver tus fotos. Para habilitarlo, abre '
      'los Ajustes del teléfono, busca MacroFit y permite el acceso a fotos. También puedes tomar la foto con la cámara.';
  static const cameraUnavailableMessage =
      'No pudimos abrir la cámara de este dispositivo. Elige una foto de la galería.';

  PickedPhoto? _photo;
  UploadedPhoto? _uploaded;
  String? _error;
  bool _isPicking = false;
  bool _isUploading = false;

  /// Foto elegida (vista previa).
  PickedPhoto? get photo => _photo;

  /// Foto ya guardada en el backend; su `id` es el que usa HU-07.
  UploadedPhoto? get uploaded => _uploaded;
  String? get error => _error;
  bool get isPicking => _isPicking;
  bool get isUploading => _isUploading;
  bool get isBusy => _isPicking || _isUploading;

  /// Muestra la foto que se recuperó porque Android cerró la app con la cámara
  /// abierta. Se llama al crear la pantalla.
  void restoreRecoveredPhoto() {
    final recovered = _repository.takeRecoveredPhoto();
    if (recovered == null) return;
    final invalid = MealPhotoValidator.validate(recovered.bytes);
    if (invalid != null) {
      _error = invalid;
    } else {
      _photo = recovered;
    }
    notifyListeners();
  }

  /// Abre la cámara o la galería. Cancelar conserva la foto anterior; una foto
  /// que no cumple las reglas de TEC-13 no reemplaza a la anterior.
  Future<void> pick(PhotoSource source) async {
    if (isBusy || _uploaded != null) return;
    _isPicking = true;
    _error = null;
    notifyListeners();
    try {
      final picked = await _repository.pickPhoto(source);
      if (picked != null) {
        final invalid = MealPhotoValidator.validate(picked.bytes);
        if (invalid != null) {
          _error = invalid;
        } else {
          _photo = picked;
        }
      }
    } on PhotoPickException catch (error) {
      _error = switch (error.error) {
        PhotoPickError.cameraDenied => cameraDeniedMessage,
        PhotoPickError.galleryDenied => galleryDeniedMessage,
        PhotoPickError.cameraUnavailable => cameraUnavailableMessage,
      };
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  /// Sube la foto elegida. Ante un error se conserva para reintentar o cambiarla.
  Future<void> upload() async {
    final photo = _photo;
    if (photo == null || isBusy || _uploaded != null) return;
    _isUploading = true;
    _error = null;
    notifyListeners();
    try {
      _uploaded = await _repository.uploadPhoto(photo);
      // TODO(HU-07-APP): pasar `_uploaded.id` a la estimación nutricional.
    } on ApiException catch (error) {
      _error = switch (error.code) {
        ApiErrorCode.photoTooLarge => MealPhotoValidator.tooLargeMessage,
        ApiErrorCode.unsupportedPhotoType =>
          MealPhotoValidator.unsupportedTypeMessage,
        _ => error.message,
      };
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
}
