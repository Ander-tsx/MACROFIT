import '../../domain/entities/privacy_notice.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_remote_data_source.dart';

class LegalRepositoryImpl implements LegalRepository {
  LegalRepositoryImpl(this._remote);

  final LegalRemoteDataSource _remote;

  /// El aviso no cambia mientras la app está abierta: se pide una vez.
  PrivacyNotice? _cachedNotice;

  @override
  Future<PrivacyNotice> getPrivacyNotice() async =>
      _cachedNotice ??= await _remote.getPrivacyNotice();
}
