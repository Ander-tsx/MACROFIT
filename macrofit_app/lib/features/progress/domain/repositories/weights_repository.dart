import '../entities/weight_entry.dart';

abstract class WeightsRepository {
  Future<List<WeightEntry>> getWeights();
  Future<WeightEntry> createWeight(double weightKg);
}
