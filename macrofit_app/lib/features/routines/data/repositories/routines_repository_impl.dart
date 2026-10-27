import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routines_repository.dart';
import '../datasources/routines_remote_data_source.dart';

class RoutinesRepositoryImpl implements RoutinesRepository {
  const RoutinesRepositoryImpl(this._remote);

  final RoutinesRemoteDataSource _remote;

  @override
  Future<List<Exercise>> getExercises({
    MuscleGroup? muscleGroup,
    ExerciseLevel? level,
  }) => _remote.getExercises(muscleGroup: muscleGroup, level: level);

  @override
  Future<List<Routine>> getRoutines() => _remote.getRoutines();

  @override
  Future<Routine> createRoutine(RoutineDraft draft) =>
      _remote.createRoutine(draft);

  @override
  Future<Routine> updateRoutine(String id, RoutineDraft draft) =>
      _remote.updateRoutine(id, draft);

  @override
  Future<void> deleteRoutine(String id) => _remote.deleteRoutine(id);
}
