import 'dart:typed_data';

import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';
import '../datasources/meals_remote_data_source.dart';
import '../models/meal_model.dart';

class MealsRepositoryImpl implements MealsRepository {
  const MealsRepositoryImpl(this._remote);

  final MealsRemoteDataSource _remote;

  @override
  Future<MealEstimate> estimate(String photoId) async =>
      (await _remote.estimate(photoId)).toEntity();

  @override
  Future<Meal> createMeal(NewMeal meal) async =>
      (await _remote.create(NewMealModel.fromEntity(meal))).toEntity();

  @override
  Future<List<Meal>> getMeals(DateTime day) async => [
    for (final meal in await _remote.list(day)) meal.toEntity(),
  ];

  @override
  Future<void> deleteMeal(String id) => _remote.delete(id);

  @override
  Future<Uint8List> getMealPhoto(String photoId) => _remote.photo(photoId);
}
