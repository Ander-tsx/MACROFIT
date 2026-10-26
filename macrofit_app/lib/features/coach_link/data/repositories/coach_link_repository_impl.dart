import '../../domain/repositories/coach_link_repository.dart';
import '../datasources/coach_link_remote_data_source.dart';
import '../models/coach_link_model.dart';

class CoachLinkRepositoryImpl implements CoachLinkRepository {
  const CoachLinkRepositoryImpl(this._remoteDataSource);

  final CoachLinkRemoteDataSource _remoteDataSource;

  @override
  Future<CoachLinkModel> linkCoach(String inviteCode) {
    return _remoteDataSource.linkCoach(inviteCode);
  }

  @override
  Future<void> unlinkCoach() {
    return _remoteDataSource.unlinkCoach();
  }
}
