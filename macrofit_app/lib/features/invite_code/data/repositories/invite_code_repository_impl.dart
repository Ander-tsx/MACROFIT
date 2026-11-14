import '../../domain/repositories/invite_code_repository.dart';
import '../datasources/invite_code_remote_data_source.dart';

class InviteCodeRepositoryImpl implements InviteCodeRepository {
  const InviteCodeRepositoryImpl(this._remote);

  final InviteCodeRemoteDataSource _remote;

  @override
  Future<String> getInviteCode() async =>
      (await _remote.getInviteCode()).toEntity();

  @override
  Future<String> regenerateInviteCode() async =>
      (await _remote.regenerateInviteCode()).toEntity();
}
