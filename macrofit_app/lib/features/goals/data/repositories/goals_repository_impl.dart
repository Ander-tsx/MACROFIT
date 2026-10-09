import '../../domain/entities/nutritional_goal.dart';
import '../../domain/repositories/goals_repository.dart';
import '../datasources/goals_remote_datasource.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  final GoalsRemoteDataSource remote;

  const GoalsRepositoryImpl(this.remote);

  @override
  Future<NutritionalGoal> getCurrentGoal() => remote.getCurrentGoal();

  @override
  Future<List<NutritionalGoal>> getGoalsHistory() => remote.getGoalsHistory();
}
