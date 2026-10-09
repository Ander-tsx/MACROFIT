import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Profile> getProfile() async => (await _remote.get()).toEntity();

  @override
  Future<Profile> createProfile(Profile profile) async =>
      (await _remote.create(ProfileModel.fromEntity(profile))).toEntity();

  @override
  Future<Profile> updateProfile(Profile profile) async =>
      (await _remote.update(ProfileModel.fromEntity(profile))).toEntity();
}
