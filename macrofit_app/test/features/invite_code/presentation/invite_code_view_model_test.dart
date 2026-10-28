import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/invite_code/domain/invite_share_message.dart';
import 'package:macrofit_app/features/invite_code/presentation/invite_code/invite_code_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeInviteCodeRepository repository;
  late FakeShareService share;

  InviteCodeViewModel build() {
    repository = FakeInviteCodeRepository();
    share = FakeShareService();
    return InviteCodeViewModel(repository: repository, shareService: share);
  }

  Future<bool> accept() async => true;
  Future<bool> cancel() async => false;

  group('carga', () {
    test('trae el código de 6 caracteres del coach', () async {
      final viewModel = build();
      expect(viewModel.code, isNull);
      expect(viewModel.canUseCode, isFalse);

      final loading = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      await loading;

      expect(viewModel.code, testInviteCode);
      expect(viewModel.code, hasLength(6));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loadError, isNull);
      expect(viewModel.canUseCode, isTrue);
      expect(repository.getCalls, 1);
    });

    test('sin red muestra el error y al reintentar carga el código', () async {
      final viewModel = build();
      repository.error = networkError;

      await viewModel.load();
      expect(viewModel.code, isNull);
      expect(viewModel.loadError, networkError.message);
      expect(viewModel.canUseCode, isFalse);

      repository.error = null;
      await viewModel.load();
      expect(viewModel.code, testInviteCode);
      expect(viewModel.loadError, isNull);
      expect(repository.getCalls, 2);
    });

    test('no repite la petición mientras ya está cargando', () async {
      final viewModel = build();
      await Future.wait([viewModel.load(), viewModel.load()]);
      expect(repository.getCalls, 1);
    });
  });

  group('regeneración', () {
    test('confirmada muestra el código nuevo', () async {
      final viewModel = build();
      await viewModel.load();

      final changed = await viewModel.regenerate(accept);

      expect(changed, isTrue);
      expect(viewModel.code, 'N3W8CD');
      expect(viewModel.code, isNot(testInviteCode));
      expect(viewModel.isRegenerating, isFalse);
      expect(viewModel.regenerateError, isNull);
      expect(repository.regenerateCalls, 1);
    });

    test('marca el estado mientras se regenera', () async {
      final viewModel = build();
      await viewModel.load();

      final gate = repository.regenerateGate = Completer<void>();

      final regenerating = viewModel.regenerate(accept);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isRegenerating, isTrue);
      expect(viewModel.canUseCode, isFalse);
      expect(viewModel.code, testInviteCode);

      gate.complete();
      await regenerating;
      expect(viewModel.isRegenerating, isFalse);
    });

    test('cancelada no llama a la API y conserva el código', () async {
      final viewModel = build();
      await viewModel.load();
      var asked = 0;

      final changed = await viewModel.regenerate(() async {
        asked++;
        return cancel();
      });

      expect(asked, 1);
      expect(changed, isFalse);
      expect(viewModel.code, testInviteCode);
      expect(repository.regenerateCalls, 0);
    });

    test('sin red conserva el código anterior y muestra el error', () async {
      final viewModel = build();
      await viewModel.load();
      repository.regenerateError = networkError;

      final changed = await viewModel.regenerate(accept);

      expect(changed, isFalse);
      expect(viewModel.code, testInviteCode);
      expect(viewModel.regenerateError, networkError.message);
      expect(viewModel.isRegenerating, isFalse);

      repository.regenerateError = null;
      expect(await viewModel.regenerate(accept), isTrue);
      expect(viewModel.code, 'N3W8CD');
      expect(viewModel.regenerateError, isNull);
    });

    test('sin código cargado no pide confirmación', () async {
      final viewModel = build();
      var asked = false;

      final changed = await viewModel.regenerate(() async => asked = true);

      expect(changed, isFalse);
      expect(asked, isFalse);
      expect(repository.regenerateCalls, 0);
    });
  });

  group('copiar y compartir', () {
    test('copiar pone solo el código en el portapapeles', () async {
      final viewModel = build();
      await viewModel.load();

      expect(await viewModel.copy(), isTrue);
      expect(share.copied, [testInviteCode]);
    });

    test('compartir manda el mensaje con el código y el origen', () async {
      final viewModel = build();
      await viewModel.load();
      const origin = Rect.fromLTWH(10, 20, 100, 40);

      await viewModel.share(origin: origin);

      final sent = share.shared.single;
      expect(sent.text, inviteShareMessage(testInviteCode));
      expect(sent.text, contains(testInviteCode));
      expect(sent.subject, inviteShareSubject);
      expect(sent.origin, origin);
    });

    test('después de regenerar se comparte el código nuevo', () async {
      final viewModel = build();
      await viewModel.load();
      await viewModel.regenerate(accept);

      await viewModel.copy();
      await viewModel.share();

      expect(share.copied, ['N3W8CD']);
      expect(share.shared.single.text, contains('N3W8CD'));
    });

    test('sin código no copia ni comparte', () async {
      final viewModel = build();

      expect(await viewModel.copy(), isFalse);
      await viewModel.share();

      expect(share.copied, isEmpty);
      expect(share.shared, isEmpty);
    });
  });
}
