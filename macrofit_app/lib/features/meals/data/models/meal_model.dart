import '../../domain/entities/meal.dart';
import 'meal_estimate_model.dart';

/// Cuerpo de `POST /meals`: valores finales planos, `photo_id` y `estimated`
/// solo si los hay (una captura manual no los manda).
class NewMealModel {
  const NewMealModel({required this.values, this.photoId, this.estimated});

  factory NewMealModel.fromEntity(NewMeal meal) => NewMealModel(
    photoId: meal.photoId,
    values: NutritionValuesModel.fromEntity(meal.values),
    estimated: switch (meal.estimated) {
      final estimated? => NutritionValuesModel.fromEntity(estimated),
      null => null,
    },
  );

  final String? photoId;
  final NutritionValuesModel values;
  final NutritionValuesModel? estimated;

  Map<String, dynamic> toJson() => {
    if (photoId != null) 'photo_id': photoId,
    ...values.toJson(),
    if (estimated != null) 'estimated': estimated!.toJson(),
  };
}

/// Registro de `POST /meals` (y de `GET /meals?date=`, HU-09):
/// `{ id, photo_id, eaten_at, date, calories_kcal, protein_g, fat_g, estimated }`.
class MealModel {
  const MealModel({
    required this.id,
    required this.photoId,
    required this.eatenAt,
    required this.date,
    required this.values,
    required this.estimated,
  });

  factory MealModel.fromJson(Map<String, dynamic> json) => MealModel(
    id: json['id'] as String,
    photoId: json['photo_id'] as String?,
    eatenAt: DateTime.parse(json['eaten_at'] as String),
    date: json['date'] as String,
    values: NutritionValuesModel.fromJson(json),
    estimated: switch (json['estimated']) {
      final Map<String, dynamic> estimated => NutritionValuesModel.fromJson(
        estimated,
      ),
      _ => null,
    },
  );

  final String id;
  final String? photoId;
  final DateTime eatenAt;

  /// `YYYY-MM-DD`.
  final String date;
  final NutritionValuesModel values;
  final NutritionValuesModel? estimated;

  Map<String, dynamic> toJson() => {
    'id': id,
    'photo_id': photoId,
    'eaten_at': eatenAt.toUtc().toIso8601String(),
    'date': date,
    ...values.toJson(),
    'estimated': estimated?.toJson(),
  };

  Meal toEntity() {
    final [year, month, day] = date.split('-').map(int.parse).toList();
    return Meal(
      id: id,
      photoId: photoId,
      eatenAt: eatenAt,
      date: DateTime(year, month, day),
      values: values.toEntity(),
      estimated: estimated?.toEntity(),
    );
  }
}
