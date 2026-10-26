import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/invite_code/data/datasources/invite_code_remote_data_source.dart';
import 'package:macrofit_app/features/invite_code/data/repositories/invite_code_repository_impl.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;

  InviteCodeRepositoryImpl build(
    ResponseBody Function(RequestOptions) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return InviteCodeRepositoryImpl(InviteCodeRemoteDataSource(dio));
  }

  test('obtiene el código con GET /coach/invite-code', () async {
    final repository = build((_) => jsonResponse({'code': 'K7P2QX'}, 200));

    final code = await repository.getInviteCode();

    expect(code, 'K7P2QX');
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/coach/invite-code');
  });

  test('regenera con POST /coach/invite-code/regenerate', () async {
    final repository = build((_) => jsonResponse({'code': 'N3W8CD'}, 200));

    final code = await repository.regenerateInviteCode();

    expect(code, 'N3W8CD');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/coach/invite-code/regenerate');
  });

  test('un usuario sin rol coach recibe FORBIDDEN_ROLE', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.forbiddenRole, 403),
    );

    await expectLater(
      repository.getInviteCode(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.forbiddenRole)
            .having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('sin red lanza NETWORK_ERROR', () async {
    final repository = build(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      ),
    );

    await expectLater(
      repository.regenerateInviteCode(),
      throwsA(
        isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue),
      ),
    );
  });
}
