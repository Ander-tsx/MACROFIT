import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_photo.dart';
import 'package:macrofit_app/features/meals/domain/entities/photo_pick_exception.dart';
import 'package:macrofit_app/features/meals/domain/validators/meal_photo_validator.dart';
import 'package:macrofit_app/features/meals/presentation/meal_photo/meal_photo_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeMealPhotoRepository repository;
  late MealPhotoViewModel viewModel;

  setUp(() {
    repository = FakeMealPhotoRepository();
    viewModel = MealPhotoViewModel(repository);
  });

  group('elegir la foto', () {
    test(
      'con permiso, la foto de la cámara queda en la vista previa',
      () async {
        await viewModel.pick(PhotoSource.camera);

        expect(repository.picks, [PhotoSource.camera]);
        expect(viewModel.photo, testPhoto);
        expect(viewModel.error, isNull);
        expect(viewModel.isPicking, isFalse);
      },
    );

    test('cancelar conserva la foto anterior', () async {
      await viewModel.pick(PhotoSource.gallery);
      repository.nextPick = null;

      await viewModel.pick(PhotoSource.camera);

      expect(viewModel.photo, testPhoto);
      expect(viewModel.error, isNull);
    });

    test('cambiar la foto reemplaza la vista previa', () async {
      await viewModel.pick(PhotoSource.camera);
      final other = PickedPhoto(bytes: jpegBytes(64), fileName: 'otra.jpg');
      repository.nextPick = other;

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.photo, other);
    });

    test('permiso de cámara negado: explica cómo habilitarlo y ofrece la '
        'galería', () async {
      repository.pickError = const PhotoPickException(
        PhotoPickError.cameraDenied,
      );

      await viewModel.pick(PhotoSource.camera);

      expect(viewModel.error, MealPhotoViewModel.cameraDeniedMessage);
      expect(viewModel.error, contains('Ajustes'));
      expect(viewModel.error, contains('galería'));
      expect(viewModel.photo, isNull);

      // La galería sigue disponible.
      repository.pickError = null;
      await viewModel.pick(PhotoSource.gallery);
      expect(viewModel.photo, testPhoto);
      expect(viewModel.error, isNull);
    });

    test('permiso de galería negado muestra un mensaje explicativo', () async {
      repository.pickError = const PhotoPickException(
        PhotoPickError.galleryDenied,
      );

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.error, MealPhotoViewModel.galleryDeniedMessage);
    });

    test('sin cámara disponible ofrece la galería', () async {
      repository.pickError = const PhotoPickException(
        PhotoPickError.cameraUnavailable,
      );

      await viewModel.pick(PhotoSource.camera);

      expect(viewModel.error, MealPhotoViewModel.cameraUnavailableMessage);
    });

    test('una foto de más de 5 MiB no se acepta ni se sube', () async {
      repository.nextPick = PickedPhoto(
        bytes: jpegBytes(MealPhotoValidator.maxBytes + 1),
        fileName: 'enorme.jpg',
      );

      await viewModel.pick(PhotoSource.gallery);
      await viewModel.upload();

      expect(viewModel.error, MealPhotoValidator.tooLargeMessage);
      expect(viewModel.photo, isNull);
      expect(repository.uploads, isEmpty);
    });

    test('una foto que no es JPEG ni PNG no reemplaza a la anterior', () async {
      await viewModel.pick(PhotoSource.gallery);
      repository.nextPick = PickedPhoto(
        bytes: Uint8List.fromList('GIF89a'.codeUnits),
        fileName: 'animada.gif',
      );

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.error, MealPhotoValidator.unsupportedTypeMessage);
      expect(viewModel.photo, testPhoto);
    });
  });

  group('foto recuperada', () {
    test('se muestra en la vista previa y se puede subir', () async {
      repository.recovered = testPhoto;

      viewModel.restoreRecoveredPhoto();
      await viewModel.upload();

      expect(viewModel.photo, testPhoto);
      expect(repository.hasRecoveredPhoto, isFalse);
      expect(repository.uploads, [testPhoto]);
    });

    test('sin foto recuperada la pantalla empieza vacía', () {
      viewModel.restoreRecoveredPhoto();

      expect(viewModel.photo, isNull);
      expect(viewModel.error, isNull);
    });

    test('una foto recuperada que no cumple TEC-13 muestra el motivo', () {
      repository.recovered = PickedPhoto(
        bytes: Uint8List.fromList('GIF89a'.codeUnits),
        fileName: 'x.gif',
      );

      viewModel.restoreRecoveredPhoto();

      expect(viewModel.photo, isNull);
      expect(viewModel.error, MealPhotoValidator.unsupportedTypeMessage);
    });
  });

  group('subir la foto', () {
    test('sin foto no hace nada', () async {
      await viewModel.upload();
      expect(repository.uploads, isEmpty);
    });

    test('subida correcta conserva el id para HU-07', () async {
      await viewModel.pick(PhotoSource.camera);

      final pending = viewModel.upload();
      expect(viewModel.isUploading, isTrue);
      await pending;

      expect(repository.uploads, [testPhoto]);
      expect(viewModel.uploaded, testUploadedPhoto);
      expect(viewModel.uploaded!.id, testUploadedPhoto.id);
      expect(viewModel.isUploading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('el resultado une la foto y su id para la estimación', () async {
      await viewModel.pick(PhotoSource.camera);
      expect(viewModel.result, isNull);

      await viewModel.upload();

      expect(viewModel.result!.photo, testPhoto);
      expect(viewModel.result!.photoId, testUploadedPhoto.id);
    });

    test('después de subirla no se vuelve a subir ni se cambia', () async {
      await viewModel.pick(PhotoSource.camera);
      await viewModel.upload();

      await viewModel.upload();
      await viewModel.pick(PhotoSource.gallery);

      expect(repository.uploads, hasLength(1));
      expect(repository.picks, [PhotoSource.camera]);
    });

    for (final (code, status, message) in [
      (ApiErrorCode.photoTooLarge, 413, MealPhotoValidator.tooLargeMessage),
      (
        ApiErrorCode.unsupportedPhotoType,
        415,
        MealPhotoValidator.unsupportedTypeMessage,
      ),
    ]) {
      test('$status $code muestra un mensaje en español', () async {
        await viewModel.pick(PhotoSource.camera);
        repository.uploadError = apiError(code, status: status);

        await viewModel.upload();

        expect(viewModel.error, message);
        expect(viewModel.uploaded, isNull);
        expect(viewModel.photo, testPhoto);
      });
    }

    test('sin conexión muestra el error y permite reintentar', () async {
      await viewModel.pick(PhotoSource.camera);
      repository.uploadError = networkError;

      await viewModel.upload();
      expect(viewModel.error, networkError.message);
      expect(viewModel.uploaded, isNull);

      repository.uploadError = null;
      await viewModel.upload();
      expect(viewModel.error, isNull);
      expect(viewModel.uploaded, testUploadedPhoto);
    });
  });
}
