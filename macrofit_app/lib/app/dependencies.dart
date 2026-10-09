import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/dio_factory.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/session_local_data_source.dart';
import '../features/auth/data/datasources/session_remote_data_source.dart';
import '../features/auth/data/network/auth_interceptor.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/legal/data/datasources/legal_remote_data_source.dart';
import '../features/legal/data/repositories/legal_repository_impl.dart';
import '../features/legal/domain/repositories/legal_repository.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';

/// Raíz de composición: el único lugar donde se crean las implementaciones
/// concretas (capa de datos) y se conectan entre sí. El resto de la app solo
/// conoce los contratos del dominio, inyectados con `provider` en `app.dart`.
class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.legalRepository,
    required this.profileRepository,
  });

  factory AppDependencies.create(AppConfig config) {
    // Cliente público (login, registro, refresh, aviso) y cliente con sesión.
    final publicDio = createDio(config);
    final sessionDio = createDio(config);

    const local = SessionLocalDataSource(FlutterSecureStorage());
    final authRemote = AuthRemoteDataSource(publicDio);

    final interceptor = AuthInterceptor(
      local: local,
      refresh: authRemote.refresh,
      retryClient: publicDio,
    );
    sessionDio.interceptors.add(interceptor);

    final authRepository = AuthRepositoryImpl(
      authRemote: authRemote,
      sessionRemote: SessionRemoteDataSource(sessionDio),
      local: local,
    );
    interceptor.onSessionExpired = authRepository.handleSessionExpired;

    return AppDependencies(
      authRepository: authRepository,
      legalRepository: LegalRepositoryImpl(LegalRemoteDataSource(publicDio)),
      profileRepository: ProfileRepositoryImpl(
        ProfileRemoteDataSource(sessionDio),
      ),
    );
  }

  final AuthRepository authRepository;
  final LegalRepository legalRepository;
  final ProfileRepository profileRepository;
}
