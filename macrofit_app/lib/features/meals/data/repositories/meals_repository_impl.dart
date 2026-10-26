<<<<<<< HEAD
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';
import '../datasources/meals_remote_data_source.dart';
import '../models/meal_model.dart';
=======
import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';
import '../datasources/meals_remote_data_source.dart';
>>>>>>> origin/develop

class MealsRepositoryImpl implements MealsRepository {
  const MealsRepositoryImpl(this._remote);

  final MealsRemoteDataSource _remote;

  @override
  Future<MealEstimate> estimate(String photoId) async =>
      (await _remote.estimate(photoId)).toEntity();
<<<<<<< HEAD

  @override
  Future<Meal> createMeal(NewMeal meal) async =>
      (await _remote.create(NewMealModel.fromEntity(meal))).toEntity();
=======
>>>>>>> origin/develop
}
