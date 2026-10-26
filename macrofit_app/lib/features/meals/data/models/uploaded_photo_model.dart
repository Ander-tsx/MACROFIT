import '../../domain/entities/meal_photo.dart';

/// Respuesta de `POST /meals/photos`: `{ id, format, size_bytes }`.
class UploadedPhotoModel {
  const UploadedPhotoModel({
    required this.id,
    required this.format,
    required this.sizeBytes,
  });

  factory UploadedPhotoModel.fromJson(Map<String, dynamic> json) =>
      UploadedPhotoModel(
        id: json['id'] as String,
        format: json['format'] as String,
        sizeBytes: (json['size_bytes'] as num).toInt(),
      );

  final String id;
  final String format;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'format': format,
    'size_bytes': sizeBytes,
  };

  UploadedPhoto toEntity() =>
      UploadedPhoto(id: id, format: format, sizeBytes: sizeBytes);
}
