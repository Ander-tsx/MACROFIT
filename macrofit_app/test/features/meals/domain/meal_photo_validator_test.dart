import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/meals/domain/validators/meal_photo_validator.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('acepta JPEG y PNG por su contenido', () {
    expect(MealPhotoValidator.validate(jpegBytes()), isNull);
    expect(MealPhotoValidator.validate(pngBytes), isNull);
  });

  test('acepta una foto de exactamente 5 MiB', () {
    expect(
      MealPhotoValidator.validate(jpegBytes(MealPhotoValidator.maxBytes)),
      isNull,
    );
  });

  test('rechaza una foto de más de 5 MiB antes de revisar el tipo', () {
    expect(
      MealPhotoValidator.validate(Uint8List(MealPhotoValidator.maxBytes + 1)),
      MealPhotoValidator.tooLargeMessage,
    );
  });

  test('rechaza lo que no es JPEG ni PNG (p. ej. GIF o HEIC)', () {
    final gif = Uint8List.fromList('GIF89a'.codeUnits);
    expect(
      MealPhotoValidator.validate(gif),
      MealPhotoValidator.unsupportedTypeMessage,
    );
    expect(
      MealPhotoValidator.validate(Uint8List.fromList([0xFF, 0xD8])),
      MealPhotoValidator.unsupportedTypeMessage,
    );
  });

  test('rechaza una foto vacía', () {
    expect(
      MealPhotoValidator.validate(Uint8List(0)),
      MealPhotoValidator.emptyMessage,
    );
  });
}
