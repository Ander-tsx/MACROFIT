import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:macrofit_app/features/auth/data/datasources/session_remote_data_source.dart';
import 'package:macrofit_app/features/auth/data/models/session_model.dart';
import 'package:macrofit_app/features/auth/data/models/user_model.dart';
import 'package:macrofit_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';

import '../../../helpers/fakes.dart';

class _FakeAuthRemote extends AuthRemoteDataSource {
  _FakeAuthRemote() : super(Dio());

  @override
  Future<SessionModel> login({
    required String email,
    required String password,
  }) async => SessionModel(
    tokens: const TokenPair(accessToken: 'a1', refreshToken: 'r1'),
    user: userModelOf(testCoach),
  );
}

class _FakeSessionRemote extends SessionRemoteDataSource {
  _FakeSessionRemote() : super(Dio());

  ApiException? meError;
  ApiException? logoutError;
  UserModel meResult = userModelOf(testUser);
  final loggedOutWith = <String>[];

  @override
  Future<UserModel> me() async {
    if (meError case final error?) throw error;
    return meResult;
  }

  @override
  Future<void> logout(String refreshToken) async {
    loggedOutWith.add(refreshToken);
    if (logoutError case final error?) throw error;
  }
}

void main() {
  late FakeSessionLocalDataSource local;
  late _FakeSessionRemote sessionRemote;
  late AuthRepositoryImpl repository;

  AuthRepositoryImpl build() => AuthRepositoryImpl(
    authRemote: _FakeAuthRemote(),
    sessionRemote: sessionRemote,
    local: local,
  );

  setUp(() {
    sessionRemote = _FakeSessionRemote();
  });

  group('restaurar sesión al abrir la app', () {
    test('sin sesión guardada queda sin sesión', () async {
      local = FakeSessionLocalDataSource();
      repository = build();

      await repository.restoreSession();

      expect(repository.state, isA<Unauthenticated>());
    });

    test('con sesión guardada entra de inmediato y actualiza el usuario con /auth/me', () async {
      local = FakeSessionLocalDataSource(
        tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
        user: userModelOf(testUser),
      );
      sessionRemote.meResult = userModelOf(testUser).copyWithName('Ana María');
      repository = build();

      await repository.restoreSession();
      expect(repository.state, isA<Authenticated>());

      await pumpEventQueue();
      expect(repository.currentUser?.name, 'Ana María');
    });

    test('sin red conserva la sesión guardada', () async {
      local = FakeSessionLocalDataSource(
        tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
        user: userModelOf(testUser),
      );
      sessionRemote.meError = networkError;
      repository = build();

      await repository.restoreSession();
      await pumpEventQueue();

      expect(repository.currentUser, testUser);
      expect(local.tokens, isNotNull);
    });

    test('si el backend rechaza la sesión (401) se cierra', () async {
      local = FakeSessionLocalDataSource(
        tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
        user: userModelOf(testUser),
      );
      sessionRemote.meError = apiError(ApiErrorCode.tokenRevoked, status: 401);
      repository = build();

      await repository.restoreSession();
      await pumpEventQueue();

      expect(repository.state, isA<Unauthenticated>());
      expect(local.tokens, isNull);
    });
  });

  test('login guarda los tokens y queda autenticado con su rol', () async {
    local = FakeSessionLocalDataSource();
    repository = build();

    final user = await repository.login(
      email: 'c@macrofit.test',
      password: 'x',
    );

    expect(user, testCoach);
    expect(local.tokens?.refreshToken, 'r1');
    expect(repository.state, isA<Authenticated>());
  });

  group('cerrar sesión', () {
    setUp(() {
      local = FakeSessionLocalDataSource(
        tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
        user: userModelOf(testUser),
      );
    });

    test(
      'revoca en el backend con el refresh token y borra lo local',
      () async {
        repository = build();
        await repository.restoreSession();

        await repository.logout();

        expect(sessionRemote.loggedOutWith, ['r']);
        expect(local.tokens, isNull);
        expect(repository.state, isA<Unauthenticated>());
      },
    );

    test('borra la sesión local aunque el servidor no responda', () async {
      sessionRemote.logoutError = networkError;
      repository = build();
      await repository.restoreSession();

      await repository.logout();

      expect(local.tokens, isNull);
      expect(repository.state, isA<Unauthenticated>());
    });
  });

  group('perfil completado (HU-03)', () {
    test('marca la sesión y el usuario guardado con perfil', () async {
      local = FakeSessionLocalDataSource(
        tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
        user: userModelOf(testNewUser),
      );
      sessionRemote.meResult = userModelOf(testNewUser);
      repository = build();
      await repository.restoreSession();
      await pumpEventQueue();
      var notifications = 0;
      repository.addListener(() => notifications++);

      await repository.markProfileCompleted();

      expect(repository.currentUser?.profileCompleted, isTrue);
      expect((await local.read())?.user.profileCompleted, isTrue);
      expect(notifications, 1);
    });

    test('sin sesión no hace nada', () async {
      local = FakeSessionLocalDataSource();
      repository = build();
      await repository.restoreSession();

      await repository.markProfileCompleted();

      expect(repository.state, isA<Unauthenticated>());
    });
  });
}

extension on UserModel {
  UserModel copyWithName(String name) => UserModel(
    id: id,
    name: name,
    email: email,
    role: role,
    profileCompleted: profileCompleted,
  );
}
