import '../../domain/entities/user_routine.dart';
import '../../domain/repositories/my_routines_repository.dart';
import '../datasources/my_routines_remote_data_source.dart';

class MyRoutinesRepositoryImpl implements MyRoutinesRepository {
  const MyRoutinesRepositoryImpl(this._remote);

  final MyRoutinesRemoteDataSource _remote;

  @override
  Future<List<UserRoutineSummary>> getRoutines() => _remote.getRoutines();

  @override
  Future<UserRoutine> getRoutine(String id) => _remote.getRoutine(id);

  @override
  Future<UserRoutine> requestRecommendedRoutine() =>
      _remote.requestRecommendedRoutine();
}
