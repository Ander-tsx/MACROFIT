/// Calorías, proteína y grasa de una comida o de un alimento.
class NutritionValues {
  const NutritionValues({
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
  });

  final double caloriesKcal;
  final double proteinG;
  final double fatG;

  @override
  bool operator ==(Object other) =>
      other is NutritionValues &&
      other.caloriesKcal == caloriesKcal &&
      other.proteinG == proteinG &&
      other.fatG == fatG;

  @override
  int get hashCode => Object.hash(caloriesKcal, proteinG, fatG);
}

/// Alimento identificado en la foto (RF-06).
class EstimatedFood {
  const EstimatedFood({required this.name, required this.values, this.grams});

  final String name;

  /// Porción estimada; `null` si el servicio no la estima.
  final double? grams;
  final NutritionValues values;

  @override
  bool operator ==(Object other) =>
      other is EstimatedFood &&
      other.name == name &&
      other.grams == grams &&
      other.values == values;

  @override
  int get hashCode => Object.hash(name, grams, values);
}

/// Estimación nutricional de una foto (`POST /meals/estimate`, HU-07).
/// No se guarda: la persona la revisa y la corrige antes de registrar (HU-08).
class MealEstimate {
  const MealEstimate({
    required this.photoId,
    required this.foods,
    required this.totals,
  });

  final String photoId;

  /// Nunca está vacía (el backend responde `422` si no reconoce comida).
  final List<EstimatedFood> foods;
  final NutritionValues totals;
}
