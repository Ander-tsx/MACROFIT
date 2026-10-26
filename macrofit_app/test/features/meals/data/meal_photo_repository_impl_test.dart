import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/data/datasources/meal_photos_remote_data_source.dart';
import 'package:macrofit_app/features/meals/data/datasources/photo_picker_data_source.dart';
import 'package:macrofit_app/features/meals/data/models/uploaded_photo_model.dart';
import 'package:macrofit_app/features/meals/data/repositories/meal_photo_repository_impl.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_photo.dart';
import 'package:macrofit_app/features/meals/domain/entities/photo_pick_exception.dart';

import '../../../helpers/fakes.dart';

/// Sustituye a la cámara y la galería del dispositivo.
class _FakeImagePicker extends ImagePicker {
  XFile? result;
  PlatformException? error;
  final calls =
      <
        ({
          ImageSource source,
          double? maxWidth,
          double? maxHeight,
          int? imageQuality,
        })
      >[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add((
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    ));
    if (error case final error?) throw error;
    return result;
  }

  /// Respuesta de `retrieveLostData`; `null` = la plataforma no lo implementa.
  LostDataResponse? lost = LostDataResponse.empty();

  @override
  Future<LostDataResponse> retrieveLostData() async {
    final lost = this.lost;
    if (lost == null) throw UnimplementedError();
    return lost;
  }
}

void main() {
  late FakeHttpAdapter adapter;
  late _FakeImagePicker picker;

  MealPhotoRepositoryImpl build([
    ResponseBody Function(RequestOptions)? handler,
  ]) {
    adapter = FakeHttpAdapter(
      handler ??
          (_) => jsonResponse({
            'id': testUploadedPhoto.id,
            'format': 'jpeg',
            'size_bytes': 32,
          }, 201),
    );
    picker = _FakeImagePicker();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return MealPhotoRepositoryImpl(
      picker: PhotoPickerDataSource(picker),
      remote: MealPhotosRemoteDataSource(dio),
    );
  }

  group('subida (POST /meals/photos)', () {
    test('manda la foto en el campo photo como multipart', () async {
      final repository = build();

      final uploaded = await repository.uploadPhoto(testPhoto);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/meals/photos');
      expect(request.contentType, startsWith('multipart/form-data'));
      final form = request.data as FormData;
      expect(form.files.single.key, 'photo');
      expect(form.files.single.value.filename, 'comida.png');
      expect(form.files.single.value.length, testPhoto.sizeBytes);
      expect(uploaded, testUploadedPhoto);
    });

    for (final (code, status) in [
      (ApiErrorCode.photoTooLarge, 413),
      (ApiErrorCode.unsupportedPhotoType, 415),
    ]) {
      test('$status se traduce a ApiException $code', () async {
        final repository = build((_) => errorResponse(code, status));

        await expectLater(
          repository.uploadPhoto(testPhoto),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    test('sin conexión lanza NETWORK_ERROR', () async {
      final repository = build(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'sin red',
        ),
      );

      await expectLater(
        repository.uploadPhoto(testPhoto),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'red', isTrue)),
      );
    });
  });

  group('foto perdida (Android cerró la app con la cámara abierta)', () {
    test('se recupera una vez y después ya no está', () async {
      final repository = build();
      picker.lost = LostDataResponse(
        file: XFile.fromData(pngBytes, name: 'scaled_1.png'),
        type: RetrieveType.image,
      );

      await repository.recoverLostPhoto();

      expect(repository.hasRecoveredPhoto, isTrue);
      expect(repository.takeRecoveredPhoto()!.bytes, pngBytes);
      expect(repository.hasRecoveredPhoto, isFalse);
      expect(repository.takeRecoveredPhoto(), isNull);
    });

    test('sin foto pendiente no hay nada que recuperar', () async {
      final repository = build();

      await repository.recoverLostPhoto();

      expect(repository.hasRecoveredPhoto, isFalse);
    });

    test('en plataformas sin soporte (iOS) no falla', () async {
      final repository = build();
      picker.lost = null;

      await repository.recoverLostPhoto();

      expect(repository.hasRecoveredPhoto, isFalse);
    });

    test('si la captura perdida terminó en error no hay foto', () async {
      final repository = build();
      picker.lost = LostDataResponse(
        exception: PlatformException(code: 'camera_access_denied'),
        type: RetrieveType.image,
      );

      await repository.recoverLostPhoto();

      expect(repository.hasRecoveredPhoto, isFalse);
    });
  });

  group('cámara y galería', () {
    test('pide la foto comprimida al origen elegido', () async {
      final repository = build();
      picker.result = XFile.fromData(
        pngBytes,
        name: 'IMG_0001.png',
        path: 'cache${Platform.pathSeparator}IMG_0001.png',
      );

      final photo = await repository.pickPhoto(PhotoSource.camera);

      expect(photo!.bytes, pngBytes);
      expect(photo.fileName, 'IMG_0001.png');
      final call = picker.calls.single;
      expect(call.source, ImageSource.camera);
      expect(call.maxWidth, PhotoPickerDataSource.maxDimension);
      expect(call.maxHeight, PhotoPickerDataSource.maxDimension);
      expect(call.imageQuality, lessThan(100));

      await repository.pickPhoto(PhotoSource.gallery);
      expect(picker.calls.last.source, ImageSource.gallery);
    });

    test('cancelar devuelve null', () async {
      final repository = build();

      expect(await repository.pickPhoto(PhotoSource.gallery), isNull);
    });

    for (final (code, source, expected) in [
      ('camera_access_denied', PhotoSource.camera, PhotoPickError.cameraDenied),
      (
        'camera_access_restricted',
        PhotoSource.camera,
        PhotoPickError.cameraDenied,
      ),
      (
        'photo_access_denied',
        PhotoSource.gallery,
        PhotoPickError.galleryDenied,
      ),
      (
        'no_available_camera',
        PhotoSource.camera,
        PhotoPickError.cameraUnavailable,
      ),
    ]) {
      test('el error $code se traduce a $expected', () async {
        final repository = build();
        picker.error = PlatformException(code: code);

        await expectLater(
          repository.pickPhoto(source),
          throwsA(
            isA<PhotoPickException>().having((e) => e.error, 'error', expected),
          ),
        );
      });
    }

    test(
      'un fallo desconocido de la galería se trata como sin acceso',
      () async {
        final repository = build();
        picker.error = PlatformException(code: 'otro');

        await expectLater(
          repository.pickPhoto(PhotoSource.gallery),
          throwsA(
            isA<PhotoPickException>().having(
              (e) => e.error,
              'error',
              PhotoPickError.galleryDenied,
            ),
          ),
        );
      },
    );
  });

  test('el modelo lee y escribe los nombres de la API', () {
    const json = {'id': 'abc', 'format': 'png', 'size_bytes': 2048};

    final model = UploadedPhotoModel.fromJson(json);

    expect(model.toJson(), json);
    expect(
      model.toEntity(),
      const UploadedPhoto(id: 'abc', format: 'png', sizeBytes: 2048),
    );
  });
}
