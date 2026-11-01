import '../../domain/entities/day_summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../datasources/summary_remote_data_source.dart';

class SummaryRepositoryImpl implements SummaryRepository {
  const SummaryRepositoryImpl(this._remote);

  final SummaryRemoteDataSource _remote;

  @override
  Future<DaySummary> getDaily(String date) => _remote.getDaily(date);
}
