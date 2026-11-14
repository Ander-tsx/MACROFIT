/// Entidad de dominio de un registro de peso (HU-21).
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
  });

  final String id;
  final double weightKg;
  final DateTime recordedAt;
}
