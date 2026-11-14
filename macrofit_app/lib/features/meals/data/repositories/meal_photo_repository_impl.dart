import '../../domain/entities/meal_photo.dart';
import '../../domain/repositories/meal_photo_repository.dart';
import '../datasources/meal_photos_remote_data_source.dart';
import '../datasources/photo_picker_data_source.dart';

class MealPhotoRepositoryImpl implements MealPhotoRepository {
  MealPhotoRepositoryImpl({required this._picker, required this._remote});

  final PhotoPickerDataSource _picker;
  final MealPhotosRemoteDataSource _remote;

  PickedPhoto? _recovered;

  @override
  Future<PickedPhoto?> pickPhoto(PhotoSource source) => _picker.pick(source);

  @override
  Future<void> recoverLostPhoto() async {
    _recovered ??= await _picker.retrieveLost();
  }

  @override
  bool get hasRecoveredPhoto => _recovered != null;

  @override
  PickedPhoto? takeRecoveredPhoto() {
    final photo = _recovered;
    _recovered = null;
    return photo;
  }

  @override
  Future<UploadedPhoto> uploadPhoto(PickedPhoto photo) async =>
      (await _remote.upload(photo)).toEntity();
}
