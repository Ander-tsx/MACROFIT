import '../../domain/entities/meal_estimate.dart';

/// `{ calories_kcal, protein_g, fat_g }`.
class NutritionValuesModel {
  const NutritionValuesModel({
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
  });

  factory NutritionValuesModel.fromJson(Map<String, dynamic> json) =>
      NutritionValuesModel(
        caloriesKcal: (json['calories_kcal'] as num).toDouble(),
        proteinG: (json['protein_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
      );

<<<<<<< HEAD
  factory NutritionValuesModel.fromEntity(NutritionValues values) =>
      NutritionValuesModel(
        caloriesKcal: values.caloriesKcal,
        proteinG: values.proteinG,
        fatG: values.fatG,
      );

=======
>>>>>>> origin/develop
  final double caloriesKcal;
  final double proteinG;
  final double fatG;

  Map<String, dynamic> toJson() => {
    'calories_kcal': caloriesKcal,
    'protein_g': proteinG,
    'fat_g': fatG,
  };

  NutritionValues toEntity() => NutritionValues(
    caloriesKcal: caloriesKcal,
    proteinG: proteinG,
    fatG: fatG,
  );
}

/// Alimento de `foods`: `{ name, grams, calories_kcal, protein_g, fat_g }`.
class EstimatedFoodModel {
  const EstimatedFoodModel({
    required this.name,
    required this.grams,
    required this.values,
  });

  factory EstimatedFoodModel.fromJson(Map<String, dynamic> json) =>
      EstimatedFoodModel(
        name: json['name'] as String,
        grams: (json['grams'] as num?)?.toDouble(),
        values: NutritionValuesModel.fromJson(json),
      );

  final String name;
  final double? grams;
  final NutritionValuesModel values;

  Map<String, dynamic> toJson() => {
    'name': name,
    'grams': grams,
    ...values.toJson(),
  };

  EstimatedFood toEntity() =>
      EstimatedFood(name: name, grams: grams, values: values.toEntity());
}

/// Respuesta `200` de `POST /meals/estimate`: `{ photo_id, foods, totals }`.
class MealEstimateModel {
  const MealEstimateModel({
    required this.photoId,
    required this.foods,
    required this.totals,
  });

  factory MealEstimateModel.fromJson(Map<String, dynamic> json) =>
      MealEstimateModel(
        photoId: json['photo_id'] as String,
        foods: [
          for (final food in json['foods'] as List<dynamic>)
            EstimatedFoodModel.fromJson(food as Map<String, dynamic>),
        ],
        totals: NutritionValuesModel.fromJson(
          json['totals'] as Map<String, dynamic>,
        ),
      );

  final String photoId;
  final List<EstimatedFoodModel> foods;
  final NutritionValuesModel totals;

  Map<String, dynamic> toJson() => {
    'photo_id': photoId,
    'foods': [for (final food in foods) food.toJson()],
    'totals': totals.toJson(),
  };

  MealEstimate toEntity() => MealEstimate(
    photoId: photoId,
    foods: [for (final food in foods) food.toEntity()],
    totals: totals.toEntity(),
  );
}
