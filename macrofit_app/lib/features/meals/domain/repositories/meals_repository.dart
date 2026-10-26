<<<<<<< HEAD
import '../entities/meal.dart';
=======
>>>>>>> origin/develop
import '../entities/meal_estimate.dart';

/// Registros de comida del usuario (HU-07 en adelante).
abstract interface class MealsRepository {
  /// `POST /meals/estimate` con el id de una foto subida (HU-06). Lanza
  /// `ApiException`: `FOOD_NOT_RECOGNIZED` (422), `FOOD_PROVIDER_ERROR` (502),
  /// `FOOD_PROVIDER_TIMEOUT` (504) o sin red, entre otros.
  Future<MealEstimate> estimate(String photoId);
<<<<<<< HEAD

  /// `POST /meals` (HU-08). Lanza `ApiException`: `VALIDATION_ERROR` con
  /// `fields` (incluidos `estimated.<campo>`), `PHOTO_NOT_FOUND`,
  /// `PHOTO_ALREADY_USED` o sin red, entre otros.
  Future<Meal> createMeal(NewMeal meal);
=======
>>>>>>> origin/develop
}
