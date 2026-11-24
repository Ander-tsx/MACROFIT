import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/coach_link/data/datasources/coach_link_remote_data_source.dart';
import 'package:macrofit_app/features/coach_link/data/repositories/coach_link_repository_impl.dart';

import '../../../helpers/fakes.dart';

const _link = {
  'id': 'l1',
  'coach_id': 'c1',
  'coach_name': 'Laura',
  'coach_email': 'laura@macrofit.test',
  'status': 'active',
};

void main() {
  late FakeHttpAdapter adapter;

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  CoachLinkRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return CoachLinkRepositoryImpl(
      CoachLinkRemoteDataSource(dio),
      const FlutterSecureStorage(),
    );
  }

  test(
    'la vista previa pide GET /users/me/coach-link/preview con el código',
    () async {
      final repository = build(
        (_) => jsonResponse({'coach_name': 'Laura'}, 200),
      );

      final name = await repository.previewCoach('K7P2QX');

      expect(name, 'Laura');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/me/coach-link/preview');
      expect(request.queryParameters, {'invite_code': 'K7P2QX'});
    },
  );

  test(
    'la vista previa de un código inexistente lanza INVITE_CODE_NOT_FOUND',
    () async {
      final repository = build(
        (_) => errorResponse(ApiErrorCode.inviteCodeNotFound, 404),
      );

      await expectLater(
        repository.previewCoach('ZZZZZZ'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.inviteCodeNotFound,
          ),
        ),
      );
    },
  );

  test('vincular envía POST /users/me/coach-link con el código', () async {
    final repository = build((_) => jsonResponse(_link, 201));

    final link = await repository.linkCoach('K7P2QX');

    expect(link.coachName, 'Laura');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/users/me/coach-link');
    expect(request.data, {'invite_code': 'K7P2QX'});
  });

  test('sin conexión se muestra la última vinculación guardada', () async {
    var online = true;
    final repository = build((options) {
      if (!online) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'sin red',
        );
      }
      return jsonResponse(_link, 200);
    });

    await repository.getLinkedCoach();
    online = false;
    final cached = await repository.getLinkedCoach();

    expect(cached?.coachName, 'Laura');
  });

  test('desvincularse envía DELETE y olvida la vinculación guardada', () async {
    var linked = true;
    final repository = build((options) {
      if (options.method == 'DELETE') {
        linked = false;
        return ResponseBody.fromString('', 204);
      }
      if (linked) return jsonResponse(_link, 200);
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      );
    });

    await repository.getLinkedCoach();
    await repository.unlinkCoach();

    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/users/me/coach-link');
    // Sin red ya no queda una vinculación guardada que mostrar.
    expect(await repository.getLinkedCoach(), isNull);
  });

  test('USER_NOT_LINKED al desvincularse no es un error', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.userNotLinked, 404),
    );

    await expectLater(repository.unlinkCoach(), completes);
  });
}
