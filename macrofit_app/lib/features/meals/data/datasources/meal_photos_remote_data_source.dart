import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../../domain/entities/meal_photo.dart';
import '../models/uploaded_photo_model.dart';

/// Endpoints de fotos de comida (rol `user`).
class MealPhotosRemoteDataSource {
  const MealPhotosRemoteDataSource(this._dio);

  final Dio _dio;

  /// Una foto de hasta 5 MiB puede tardar en subir con datos móviles.
  static const _uploadTimeout = Duration(seconds: 60);

  /// HU-06 — `POST /meals/photos`, multipart con el archivo en el campo `photo`.
  /// El backend revisa el tipo por el contenido; el nombre es informativo.
  Future<UploadedPhotoModel> upload(PickedPhoto photo) => guardApiCall(
    () async {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(photo.bytes, filename: photo.fileName),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/meals/photos',
        data: form,
        options: Options(
          sendTimeout: _uploadTimeout,
          receiveTimeout: _uploadTimeout,
        ),
      );
      return UploadedPhotoModel.fromJson(response.data!);
    },
  );
}
