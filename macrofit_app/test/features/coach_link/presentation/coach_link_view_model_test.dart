import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/coach_link/domain/entities/coach_link.dart';
import 'package:macrofit_app/features/coach_link/presentation/coach_link/coach_link_view_model.dart';
import '../../../helpers/fakes.dart';

void main() {
  group('CoachLinkViewModel', () {
    test('estado inicial', () {
      final repo = FakeCoachLinkRepository();
      final vm = CoachLinkViewModel(repository: repo);

      expect(vm.inviteCode, '');
      expect(vm.isLoading, false);
      expect(vm.errorMessage, null);
      expect(vm.linkedCoach, null);
    });

    test('actualiza código y limpia error', () {
      final repo = FakeCoachLinkRepository();
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('ab3k9z');
      expect(vm.inviteCode, 'ab3k9z');
      expect(vm.errorMessage, null);
    });

    test('falla si el código está vacío', () async {
      final repo = FakeCoachLinkRepository();
      final vm = CoachLinkViewModel(repository: repo);

      final success = await vm.linkCoach();
      expect(success, false);
      expect(vm.errorMessage, 'El código de invitación es obligatorio.');
    });

    test('vinculación exitosa normaliza a mayúsculas y asigna coach_name', () async {
      final repo = FakeCoachLinkRepository(
        linkResult: const CoachLink(
          id: '1',
          coachId: 'c1',
          coachName: 'Laura',
          coachEmail: 'laura@test.com',
          status: 'active',
        ),
      );
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('  k7p2qx ');
      final success = await vm.linkCoach();

      expect(success, true);
      expect(vm.linkedCoach?.coachName, 'Laura');
      expect(vm.errorMessage, null);
    });

    test('maneja INVITE_CODE_NOT_FOUND (Código inválido)', () async {
      final repo = FakeCoachLinkRepository(
        linkException: const ApiException(
          code: ApiErrorCode.inviteCodeNotFound,
          message: 'No existe',
        ),
      );
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('invalid');
      final success = await vm.linkCoach();

      expect(success, false);
      expect(vm.errorMessage, 'Código inválido');
    });

    test('maneja USER_ALREADY_LINKED', () async {
      final repo = FakeCoachLinkRepository(
        linkException: const ApiException(
          code: ApiErrorCode.userAlreadyLinked,
          message: 'Ya vinculado',
        ),
      );
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('k7p2qx');
      final success = await vm.linkCoach();

      expect(success, false);
      expect(vm.errorMessage, contains('Primero debes desvincularte'));
    });

    test('maneja error de red (sin conexión)', () async {
      final repo = FakeCoachLinkRepository(
        linkException: const ApiException(
          code: ApiErrorCode.network,
          message: 'Sin red',
        ),
      );
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('k7p2qx');
      final success = await vm.linkCoach();

      expect(success, false);
      expect(vm.errorMessage, 'Sin red');
    });

    test('desvinculación exitosa limpia linkedCoach', () async {
      final repo = FakeCoachLinkRepository(
        linkResult: const CoachLink(
          id: '1',
          coachId: 'c1',
          coachName: 'Laura',
          coachEmail: 'laura@test.com',
          status: 'active',
        ),
      );
      final vm = CoachLinkViewModel(repository: repo);

      vm.updateInviteCode('k7p2qx');
      await vm.linkCoach();
      expect(vm.linkedCoach, isNotNull);

      final success = await vm.unlinkCoach();
      expect(success, true);
      expect(vm.linkedCoach, null);
      expect(repo.unlinkedCalled, true);
    });

    test('desvinculación con 404 USER_NOT_LINKED trata como éxito sin coach', () async {
      final repo = FakeCoachLinkRepository(
        linkedCoach: const CoachLink(
          id: '1',
          coachId: 'c1',
          coachName: 'Laura',
          coachEmail: 'laura@test.com',
          status: 'active',
        ),
      );
      repo.unlinkException = const ApiException(
        code: ApiErrorCode.userNotLinked,
        message: 'No vinculado',
      );
      final vm = CoachLinkViewModel(repository: repo);

      await vm.load();
      expect(vm.linkedCoach, isNotNull);

      final success = await vm.unlinkCoach();
      expect(success, true);
      expect(vm.linkedCoach, null);
      expect(vm.errorMessage, null);
    });
  });
}
