import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/coach_link/data/models/coach_link_model.dart';
import 'package:macrofit_app/features/coach_link/domain/repositories/coach_link_repository.dart';
import 'package:macrofit_app/features/coach_link/presentation/coach_link/coach_link_view_model.dart';

class FakeCoachLinkRepository implements CoachLinkRepository {
  FakeCoachLinkRepository({
    this.linkResult,
    this.linkException,
    this.shouldThrowOnUnlink = false,
  });

  CoachLinkModel? linkResult;
  Exception? linkException;
  bool shouldThrowOnUnlink;
  bool unlinkedCalled = false;

  @override
  Future<CoachLinkModel> linkCoach(String inviteCode) async {
    if (linkException != null) throw linkException!;
    return linkResult ??
        const CoachLinkModel(
          id: '1',
          coachId: 'coach1',
          coachName: 'Coach Test',
          coachEmail: 'coach@test.com',
          status: 'active',
        );
  }

  @override
  Future<void> unlinkCoach() async {
    unlinkedCalled = true;
    if (shouldThrowOnUnlink) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Error al desvincular',
      );
    }
  }
}

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

    test(
      'vinculación exitosa normaliza a mayúsculas y asigna coach_name',
      () async {
        final repo = FakeCoachLinkRepository(
          linkResult: const CoachLinkModel(
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
      },
    );

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
        linkResult: const CoachLinkModel(
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
  });
}
