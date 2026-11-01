import 'dart:typed_data';

import '../entities/meal.dart';
import '../entities/meal_estimate.dart';

/// Registros de comida del usuario (HU-07 en adelante).
abstract interface class MealsRepository {
  /// `POST /meals/estimate` con el id de una foto subida (HU-06). Lanza
  /// `ApiException`: `FOOD_NOT_RECOGNIZED` (422), `FOOD_PROVIDER_ERROR` (502),
  /// `FOOD_PROVIDER_TIMEOUT` (504) o sin red, entre otros.
  Future<MealEstimate> estimate(String photoId);

  /// `POST /meals` (HU-08). Lanza `ApiException`: `VALIDATION_ERROR` con
  /// `fields` (incluidos `estimated.<campo>`), `PHOTO_NOT_FOUND`,
  /// `PHOTO_ALREADY_USED` o sin red, entre otros.
  Future<Meal> createMeal(NewMeal meal);

  /// `GET /meals?date=` (HU-09): registros de [day] (se ignora la hora), del más
  /// antiguo al más reciente; lista vacía si no hay.
  Future<List<Meal>> getMeals(DateTime day);

  /// `DELETE /meals/{id}` (HU-09). Lanza `ApiException` `MEAL_NOT_FOUND` si ya
  /// no existe.
  Future<void> deleteMeal(String id);

  /// `GET /meals/photos/{id}` (HU-09): la foto de un registro propio.
  Future<Uint8List> getMealPhoto(String photoId);
}
