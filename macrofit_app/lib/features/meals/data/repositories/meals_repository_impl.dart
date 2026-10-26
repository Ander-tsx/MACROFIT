import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';
import '../datasources/meals_remote_data_source.dart';

class MealsRepositoryImpl implements MealsRepository {
  const MealsRepositoryImpl(this._remote);

  final MealsRemoteDataSource _remote;

  @override
  Future<MealEstimate> estimate(String photoId) async =>
      (await _remote.estimate(photoId)).toEntity();
}
