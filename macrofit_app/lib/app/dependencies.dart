import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/dio_factory.dart';
import '../core/platform/share_service.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/session_local_data_source.dart';
import '../features/auth/data/datasources/session_remote_data_source.dart';
import '../features/auth/data/network/auth_interceptor.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/clients/data/datasources/clients_remote_data_source.dart';
import '../features/clients/data/repositories/clients_repository_impl.dart';
import '../features/clients/domain/repositories/clients_repository.dart';
import '../features/goals/data/datasources/goals_remote_datasource.dart';
import '../features/goals/data/repositories/goals_repository_impl.dart';
import '../features/goals/domain/repositories/coach_goals_repository.dart';
import '../features/invite_code/data/datasources/invite_code_remote_data_source.dart';
import '../features/invite_code/data/repositories/invite_code_repository_impl.dart';
import '../features/invite_code/domain/repositories/invite_code_repository.dart';
import '../features/legal/data/datasources/legal_remote_data_source.dart';
import '../features/legal/data/repositories/legal_repository_impl.dart';
import '../features/legal/domain/repositories/legal_repository.dart';
import '../features/meals/data/datasources/meal_photos_remote_data_source.dart';
import '../features/meals/data/datasources/photo_picker_data_source.dart';
import '../features/meals/data/repositories/meal_photo_repository_impl.dart';
import '../features/meals/domain/repositories/meal_photo_repository.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/weights/data/datasources/weights_remote_data_source.dart';
import '../features/weights/data/repositories/weights_repository_impl.dart';
import '../features/weights/domain/repositories/weights_repository.dart';

/// Raíz de composición: el único lugar donde se crean las implementaciones
/// concretas (capa de datos) y se conectan entre sí. El resto de la app solo
/// conoce los contratos del dominio, inyectados con `provider` en `app.dart`.
class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.legalRepository,
    required this.profileRepository,
    required this.coachGoalsRepository,
    required this.mealPhotoRepository,
    required this.clientsRepository,
    required this.inviteCodeRepository,
    required this.weightsRepository,
    required this.shareService,
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
      coachGoalsRepository: CoachGoalsRepositoryImpl(
        GoalsRemoteDataSource(sessionDio),
      ),
      mealPhotoRepository: MealPhotoRepositoryImpl(
        picker: PhotoPickerDataSource(),
        remote: MealPhotosRemoteDataSource(sessionDio),
      ),
      clientsRepository: ClientsRepositoryImpl(
        ClientsRemoteDataSource(sessionDio),
      ),
      inviteCodeRepository: InviteCodeRepositoryImpl(
        InviteCodeRemoteDataSource(sessionDio),
      ),
      weightsRepository: WeightsRepositoryImpl(
        WeightsRemoteDataSource(sessionDio),
      ),
      shareService: const SystemShareService(),
    );
  }

  final AuthRepository authRepository;
  final LegalRepository legalRepository;
  final ProfileRepository profileRepository;
  final CoachGoalsRepository coachGoalsRepository;
  final MealPhotoRepository mealPhotoRepository;
  final ClientsRepository clientsRepository;
  final InviteCodeRepository inviteCodeRepository;
  final WeightsRepository weightsRepository;

  /// Portapapeles y hoja de compartir del sistema (HU-12).
  final ShareService shareService;
}
