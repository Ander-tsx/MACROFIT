import '../../domain/entities/client_meal.dart';

/// Un elemento de `GET /coach/clients/{clientId}/meals` (HU-25).
class ClientMealModel extends ClientMeal {
  const ClientMealModel({
    required super.id,
    required super.eatenAt,
    required super.caloriesKcal,
    required super.proteinG,
    required super.fatG,
    super.photoUrl,
  });

  factory ClientMealModel.fromJson(Map<String, dynamic> json) =>
      ClientMealModel(
        id: json['id'] as String,
        photoUrl: json['photo_url'] as String?,
        eatenAt: DateTime.parse(json['eaten_at'] as String),
        caloriesKcal: (json['calories_kcal'] as num).toDouble(),
        proteinG: (json['protein_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
      );
}
