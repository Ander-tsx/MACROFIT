import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/data/datasources/session_local_data_source.dart';
import 'package:macrofit_app/features/auth/data/models/session_model.dart';
import 'package:macrofit_app/features/auth/data/models/user_model.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/domain/entities/registration.dart';
import 'package:macrofit_app/features/auth/domain/entities/role.dart';
import 'package:macrofit_app/features/auth/domain/entities/user.dart';
import 'package:macrofit_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:macrofit_app/features/goals/domain/entities/coach_client.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/goals/domain/repositories/coach_goals_repository.dart';
import 'package:macrofit_app/features/legal/domain/entities/privacy_notice.dart';
import 'package:macrofit_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/domain/repositories/profile_repository.dart';

/// Usuario que ya capturó su perfil (HU-03): entra a la pantalla principal.
const testUser = User(
  id: '6ac67c707314ad6c7164900b',
  name: 'Ana',
  email: 'ana@macrofit.test',
  role: Role.user,
  profileCompleted: true,
);

/// Usuario recién registrado, sin perfil: el router lo manda al formulario (HU-03).
const testNewUser = User(
  id: '6ac67c727314ad6c7164900d',
  name: 'Beto',
  email: 'beto@macrofit.test',
  role: Role.user,
  profileCompleted: false,
);

const testCoach = User(
  id: '6ac67c717314ad6c7164900c',
  name: 'Carlos',
  email: 'carlos@macrofit.test',
  role: Role.coach,
  profileCompleted: false,
);

UserModel userModelOf(User user) => UserModel(
  id: user.id,
  name: user.name,
  email: user.email,
  role: user.role.apiValue,
  profileCompleted: user.profileCompleted,
);

ApiException apiError(
  String code, {
  int status = 400,
  Map<String, String> fields = const {},
  String message = 'Mensaje del servidor',
}) => ApiException(
  code: code,
  message: message,
  fields: fields,
  statusCode: status,
);

const networkError = ApiException(
  code: ApiErrorCode.network,
  message: 'Sin conexión',
);

/// Repositorio de autenticación en memoria para probar ViewModels y vistas.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({AuthState initialState = const Unauthenticated()})
    : _state = initialState;

  AuthState _state;

  /// Si se asigna, la siguiente llamada lanza este error.
  ApiException? registerError;
  ApiException? loginError;

  final registrations = <Registration>[];
  final logins = <({String email, String password})>[];
  int logoutCalls = 0;

  /// Rol con el que inicia sesión `login`.
  Role loginRole = Role.user;

  /// Si se asigna, `login` inicia sesión con esta cuenta (ignora [loginRole]).
  User? loginUser;

  int markProfileCompletedCalls = 0;

  @override
  AuthState get state => _state;

  void emit(AuthState state) {
    _state = state;
    notifyListeners();
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<User> register(Registration registration) async {
    registrations.add(registration);
    if (registerError case final error?) throw error;
    return User(
      id: 'nuevo',
      name: registration.name,
      email: registration.email,
      role: registration.role,
      profileCompleted: false,
    );
  }

  @override
  Future<User> login({required String email, required String password}) async {
    logins.add((email: email, password: password));
    if (loginError case final error?) throw error;
    final user = loginUser ?? (loginRole == Role.user ? testUser : testCoach);
    emit(Authenticated(user));
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    emit(const Unauthenticated());
  }

  @override
  Future<void> markProfileCompleted() async {
    markProfileCompletedCalls++;
    if (_state case Authenticated(:final user)) {
      emit(Authenticated(user.copyWith(profileCompleted: true)));
    }
  }
}

final testProfile = Profile(
  objective: Objective.loseFat,
  level: ExperienceLevel.beginner,
  trainingDays: 4,
  weightKg: 72.5,
  heightCm: 170,
  gender: Gender.female,
  birthDate: DateTime(1996, 5, 20),
);

/// Repositorio de perfil en memoria (simula al backend de HU-03).
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.stored});

  /// Perfil "guardado en el backend"; `null` = el usuario aún no tiene perfil.
  Profile? stored;

  /// Si se asigna, la siguiente llamada del tipo correspondiente lanza este error.
  ApiException? getError;
  ApiException? createError;
  ApiException? updateError;

  final created = <Profile>[];
  final updated = <Profile>[];
  int getCalls = 0;

  @override
  Future<Profile> getProfile() async {
    getCalls++;
    if (getError case final error?) throw error;
    final profile = stored;
    if (profile == null) {
      throw apiError(ApiErrorCode.profileNotFound, status: 404);
    }
    return profile;
  }

  @override
  Future<Profile> createProfile(Profile profile) async {
    created.add(profile);
    if (createError case final error?) throw error;
    if (stored != null) {
      throw apiError(ApiErrorCode.profileAlreadyExists, status: 409);
    }
    return stored = profile;
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    updated.add(profile);
    if (updateError case final error?) throw error;
    if (stored == null) {
      throw apiError(ApiErrorCode.profileNotFound, status: 404);
    }
    return stored = profile;
  }
}

const testClient = CoachClient(
  id: '6ac67c737314ad6c7164900e',
  name: 'Ana',
  email: 'ana@macrofit.test',
);

NutritionalGoal testGoal({
  int calories = 2200,
  int proteinG = 160,
  int fatG = 70,
  GoalSource source = GoalSource.coach,
  DateTime? effectiveFrom,
}) => NutritionalGoal(
  userId: testClient.id,
  calories: calories,
  proteinG: proteinG,
  fatG: fatG,
  carbsG: 0,
  source: source,
  effectiveFrom: effectiveFrom ?? DateTime(2026, 10, 9),
);

/// Repositorio de metas del coach en memoria (simula al backend de HU-05).
class FakeCoachGoalsRepository implements CoachGoalsRepository {
  FakeCoachGoalsRepository({
    this.clients = const [testClient],
    List<NutritionalGoal> history = const [],
  }) : history = [...history];

  List<CoachClient> clients;

  /// Historial del cliente, de la más reciente a la más antigua.
  final List<NutritionalGoal> history;

  /// Si se asigna, la siguiente llamada del tipo correspondiente lanza este error.
  ApiException? clientsError;
  ApiException? historyError;
  ApiException? setError;

  int clientsCalls = 0;
  final saved =
      <
        ({
          String clientId,
          int calories,
          int proteinG,
          int fatG,
          DateTime effectiveFrom,
        })
      >[];

  @override
  Future<List<CoachClient>> getClients() async {
    clientsCalls++;
    if (clientsError case final error?) throw error;
    return clients;
  }

  @override
  Future<List<NutritionalGoal>> getClientGoals(String clientId) async {
    if (historyError case final error?) throw error;
    return [...history];
  }

  @override
  Future<NutritionalGoal> setClientGoal(
    String clientId, {
    required int calories,
    required int proteinG,
    required int fatG,
    required DateTime effectiveFrom,
  }) async {
    saved.add((
      clientId: clientId,
      calories: calories,
      proteinG: proteinG,
      fatG: fatG,
      effectiveFrom: effectiveFrom,
    ));
    if (setError case final error?) throw error;
    final goal = testGoal(
      calories: calories,
      proteinG: proteinG,
      fatG: fatG,
      effectiveFrom: effectiveFrom,
    );
    history.insert(0, goal);
    return goal;
  }
}

class FakeLegalRepository implements LegalRepository {
  ApiException? error;
  int calls = 0;

  @override
  Future<PrivacyNotice> getPrivacyNotice() async {
    calls++;
    if (error case final error?) throw error;
    return const PrivacyNotice(
      version: '1.0',
      content: '# Aviso de privacidad integral de MacroFit\n\n**Versión:** 1.0',
    );
  }
}

/// Almacenamiento de sesión en memoria (sustituye a flutter_secure_storage).
class FakeSessionLocalDataSource implements SessionLocalDataSource {
  FakeSessionLocalDataSource({this._tokens, this._user});

  TokenPair? _tokens;
  UserModel? _user;
  int clearCalls = 0;

  TokenPair? get tokens => _tokens;

  @override
  Future<String?> readAccessToken() async => _tokens?.accessToken;

  @override
  Future<String?> readRefreshToken() async => _tokens?.refreshToken;

  @override
  Future<StoredSession?> read() async {
    final tokens = _tokens;
    final user = _user;
    if (tokens == null || user == null) return null;
    return StoredSession(tokens: tokens, user: user);
  }

  @override
  Future<void> save(SessionModel session) async {
    _tokens = session.tokens;
    _user = session.user;
  }

  @override
  Future<void> saveTokens(TokenPair tokens) async => _tokens = tokens;

  @override
  Future<void> saveUser(UserModel user) async => _user = user;

  @override
  Future<void> clear() async {
    clearCalls++;
    _tokens = null;
    _user = null;
  }
}

/// Adaptador HTTP de Dio que responde con [handler] sin tocar la red.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody errorResponse(String code, int status) => jsonResponse({
  'error': {'code': code, 'message': code, 'fields': <String, String>{}},
}, status);

Map<String, Object> sessionJson(
  User user, {
  required String access,
  required String refresh,
}) => {
  'access_token': access,
  'refresh_token': refresh,
  'token_type': 'Bearer',
  'expires_in': 900,
  'user': userModelOf(user).toJson(),
};
