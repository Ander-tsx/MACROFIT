import '../../data/models/weight_model.dart';

abstract class WeightsRepository {
  Future<List<WeightModel>> getWeights();
  Future<WeightModel> createWeight(double weightKg);
}
