import '../../domain/entities/weight_entry.dart';
import '../../domain/repositories/weights_repository.dart';
import '../datasources/weights_remote_data_source.dart';

class WeightsRepositoryImpl implements WeightsRepository {
  const WeightsRepositoryImpl(this._remoteDataSource);

  final WeightsRemoteDataSource _remoteDataSource;

  @override
  Future<List<WeightEntry>> getWeights() async {
    final models = await _remoteDataSource.getWeights();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<WeightEntry> createWeight(double weightKg) async {
    final model = await _remoteDataSource.createWeight(weightKg);
    return model.toEntity();
  }
}
