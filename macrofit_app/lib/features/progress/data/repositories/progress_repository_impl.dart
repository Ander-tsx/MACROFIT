import '../../domain/entities/progress_report.dart';
import '../../domain/repositories/progress_repository.dart';
import '../datasources/progress_remote_data_source.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  const ProgressRepositoryImpl(this._remote);

  final ProgressRemoteDataSource _remote;

  @override
  Future<ProgressReport> getProgress({
    required String from,
    required String to,
  }) async => (await _remote.getProgress(from: from, to: to)).toEntity();
}
