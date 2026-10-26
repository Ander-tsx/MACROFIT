import '../../domain/repositories/weights_repository.dart';
import '../datasources/weights_remote_data_source.dart';
import '../models/weight_model.dart';

class WeightsRepositoryImpl implements WeightsRepository {
  const WeightsRepositoryImpl(this._remoteDataSource);

  final WeightsRemoteDataSource _remoteDataSource;

  @override
  Future<List<WeightModel>> getWeights() => _remoteDataSource.getWeights();

  @override
  Future<WeightModel> createWeight(double weightKg) =>
      _remoteDataSource.createWeight(weightKg);
}
