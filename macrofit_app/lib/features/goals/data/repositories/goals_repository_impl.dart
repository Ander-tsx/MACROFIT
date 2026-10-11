import '../../domain/entities/coach_client.dart';
import '../../domain/entities/nutritional_goal.dart';
import '../../domain/repositories/coach_goals_repository.dart';
import '../../domain/repositories/goals_repository.dart';
import '../datasources/goals_remote_datasource.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  const GoalsRepositoryImpl(this._remote);

  final GoalsRemoteDataSource _remote;

  @override
  Future<NutritionalGoal> getCurrentGoal() => _remote.getCurrentGoal();

  @override
  Future<List<NutritionalGoal>> getGoalsHistory() => _remote.getGoalsHistory();
}

class CoachGoalsRepositoryImpl implements CoachGoalsRepository {
  const CoachGoalsRepositoryImpl(this._remote);

  final GoalsRemoteDataSource _remote;

  @override
  Future<List<CoachClient>> getClients() => _remote.getClients();

  @override
  Future<List<NutritionalGoal>> getClientGoals(String clientId) =>
      _remote.getClientGoals(clientId);

  @override
  Future<NutritionalGoal> setClientGoal(
    String clientId, {
    required int calories,
    required int proteinG,
    required int fatG,
    required DateTime effectiveFrom,
  }) => _remote.setClientGoal(
    clientId,
    calories: calories,
    proteinG: proteinG,
    fatG: fatG,
    effectiveFrom: effectiveFrom,
  );
}
