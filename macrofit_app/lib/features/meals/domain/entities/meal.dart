import 'meal_estimate.dart';
import 'meal_photo.dart';

/// Lo que recibe el formulario de valores (HU-08) según de dónde viene:
///
/// - Estimación correcta (HU-07): foto + valores estimados (precargados).
/// - Captura manual tras un fallo de la estimación: foto, sin estimados.
/// - Captura manual sin foto: ni foto ni estimados.
class MealDraft {
  const MealDraft({this.photo, this.estimated});

  final MealPhotoUpload? photo;
  final NutritionValues? estimated;

  /// Sin estimación el formulario empieza vacío y se guarda sin `estimated`.
  bool get isManual => estimated == null;
}

/// Registro por guardar (`POST /meals`). [values] son los finales (lo que la
/// persona confirmó) y [estimated] lo que estimó HU-07; `null` en una captura manual.
class NewMeal {
  const NewMeal({required this.values, this.photoId, this.estimated});

  final String? photoId;
  final NutritionValues values;
  final NutritionValues? estimated;

  @override
  bool operator ==(Object other) =>
      other is NewMeal &&
      other.photoId == photoId &&
      other.values == values &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(photoId, values, estimated);
}

/// Registro de comida guardado (respuesta de `POST /meals`).
class Meal {
  const Meal({
    required this.id,
    required this.eatenAt,
    required this.date,
    required this.values,
    this.photoId,
    this.estimated,
  });

  final String id;
  final String? photoId;

  /// Fecha y hora en que se guardó (la pone el servidor).
  final DateTime eatenAt;

  /// Día del registro en la zona horaria de la app (`APP_UTC_OFFSET` del backend).
  final DateTime date;
  final NutritionValues values;
  final NutritionValues? estimated;
}
