/// Modelo de un registro de peso (HU-21).
class WeightModel {
  const WeightModel({
    required this.id,
    required this.userId,
    required this.weightKg,
    required this.recordedAt,
  });

  factory WeightModel.fromJson(Map<String, dynamic> json) {
    return WeightModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  final String id;
  final String userId;
  final double weightKg;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {'weight_kg': weightKg};
}
