import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:macrofit_app/features/auth/data/models/session_model.dart';
import 'package:macrofit_app/features/auth/data/network/auth_interceptor.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeSessionLocalDataSource local;
  late FakeHttpAdapter adapter;
  late Dio sessionDio;
  late int refreshCalls;
  late int expiredCalls;

  /// Backend simulado: el access token vigente es [validAccess]; `/auth/refresh`
  /// responde con [refreshResponse].
  void setUpBackend({
    String validAccess = 'nuevo',
    ResponseBody Function()? refreshResponse,
    ResponseBody Function(RequestOptions)? protectedResponse,
  }) {
    refreshCalls = 0;
    expiredCalls = 0;
    adapter = FakeHttpAdapter((options) {
      if (options.path == '/auth/refresh') {
        refreshCalls++;
        return refreshResponse?.call() ??
            jsonResponse(
              sessionJson(testUser, access: 'nuevo', refresh: 'r2'),
              200,
            );
      }
      if (protectedResponse != null) return protectedResponse(options);
      return options.headers['Authorization'] == 'Bearer $validAccess'
          ? jsonResponse(userModelOf(testUser).toJson(), 200)
          : errorResponse(ApiErrorCode.unauthorized, 401);
    });

    final publicDio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    sessionDio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    final interceptor = AuthInterceptor(
      local: local,
      refresh: AuthRemoteDataSource(publicDio).refresh,
      retryClient: publicDio,
    )..onSessionExpired = () => expiredCalls++;
    sessionDio.interceptors.add(interceptor);
  }

  setUp(() {
    local = FakeSessionLocalDataSource(
      tokens: const TokenPair(accessToken: 'viejo', refreshToken: 'r1'),
      user: userModelOf(testUser),
    );
  });

  test('agrega el Bearer guardado a cada petición', () async {
    setUpBackend(validAccess: 'viejo');

    await sessionDio.get<dynamic>('/auth/me');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer viejo');
    expect(refreshCalls, 0);
  });

  test(
    'access token expirado: renueva una vez, guarda los tokens y reintenta',
    () async {
      setUpBackend();

      final response = await sessionDio.get<Map<String, dynamic>>('/auth/me');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(local.tokens?.accessToken, 'nuevo');
      expect(local.tokens?.refreshToken, 'r2');
      expect(expiredCalls, 0);
    },
  );

  test('varias peticiones expiradas a la vez renuevan una sola vez', () async {
    setUpBackend();

    final responses = await Future.wait([
      sessionDio.get<dynamic>('/auth/me'),
      sessionDio.get<dynamic>('/auth/me'),
      sessionDio.get<dynamic>('/auth/me'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('renovación rechazada: borra la sesión y avisa que expiró', () async {
    setUpBackend(
      refreshResponse: () => errorResponse(ApiErrorCode.tokenRevoked, 401),
    );

    await expectLater(
      sessionDio.get<dynamic>('/auth/me'),
      throwsA(isA<DioException>()),
    );

    expect(local.tokens, isNull);
    expect(expiredCalls, 1);
  });

  test(
    'TOKEN_REVOKED en una petición: borra la sesión sin intentar renovar',
    () async {
      setUpBackend(
        protectedResponse: (_) => errorResponse(ApiErrorCode.tokenRevoked, 401),
      );

      await expectLater(
        sessionDio.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(refreshCalls, 0);
      expect(local.tokens, isNull);
      expect(expiredCalls, 1);
    },
  );

  test('sin red durante la renovación conserva la sesión', () async {
    setUpBackend(
      refreshResponse: () => throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        reason: 'sin red',
      ),
    );

    await expectLater(
      sessionDio.get<dynamic>('/auth/me'),
      throwsA(isA<DioException>()),
    );

    expect(local.tokens?.refreshToken, 'r1');
    expect(expiredCalls, 0);
  });
}
