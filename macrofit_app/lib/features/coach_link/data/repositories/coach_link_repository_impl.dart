import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/api_exception.dart';
import '../../domain/entities/coach_link.dart';
import '../../domain/repositories/coach_link_repository.dart';
import '../datasources/coach_link_remote_data_source.dart';
import '../models/coach_link_model.dart';

class CoachLinkRepositoryImpl implements CoachLinkRepository {
  const CoachLinkRepositoryImpl(this._remoteDataSource, this._storage);

  final CoachLinkRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _storage;

  static const _activeCoachKey = 'coach_link.active';

  @override
  Future<CoachLink?> getLinkedCoach() async {
    final jsonStr = await _storage.read(key: _activeCoachKey);
    if (jsonStr == null) return null;
    try {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CoachLinkModel.fromJson(jsonMap).toEntity();
    } on Object {
      return null;
    }
  }

  @override
  Future<CoachLink> linkCoach(String inviteCode) async {
    final model = await _remoteDataSource.linkCoach(inviteCode);
    await _storage.write(
      key: _activeCoachKey,
      value: jsonEncode(model.toJson()),
    );
    return model.toEntity();
  }

  @override
  Future<void> unlinkCoach() async {
    try {
      await _remoteDataSource.unlinkCoach();
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.userNotLinked) rethrow;
    } finally {
      await _storage.delete(key: _activeCoachKey);
    }
  }
}
