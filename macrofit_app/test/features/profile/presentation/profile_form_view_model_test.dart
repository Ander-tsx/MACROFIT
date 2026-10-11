import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/presentation/profile_form/profile_form_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  ProfileFormViewModel build(ProfileFormMode mode) => ProfileFormViewModel(
    profiles: profiles,
    auth: auth,
    mode: mode,
    clock: () => DateTime(2026, 10, 8),
  );

  void fillValidForm(ProfileFormViewModel viewModel) {
    viewModel
      ..setObjective(Objective.loseFat)
      ..setLevel(ExperienceLevel.beginner)
      ..setTrainingDays(4)
      ..setWeight('72,5')
      ..setHeight(' 170 ')
      ..setGender(Gender.female)
      ..setBirthDate(DateTime(1996, 5, 20, 15, 30));
  }

  setUp(() {
    auth = FakeAuthRepository(initialState: const Authenticated(testNewUser));
    profiles = FakeProfileRepository();
  });

  group('alta (perfil inicial)', () {
    test('formulario vacío: no envía y señala cada campo', () async {
      final viewModel = build(ProfileFormMode.setup);

      expect(await viewModel.submit(), isFalse);

      expect(profiles.created, isEmpty);
      expect(viewModel.fieldErrors.keys, {
        ProfileFormViewModel.objectiveField,
        ProfileFormViewModel.levelField,
        ProfileFormViewModel.trainingDaysField,
        ProfileFormViewModel.weightField,
        ProfileFormViewModel.heightField,
        ProfileFormViewModel.genderField,
        ProfileFormViewModel.birthDateField,
      });
    });

    test('valores fuera de rango se señalan sin enviar', () async {
      final viewModel = build(ProfileFormMode.setup);
      fillValidForm(viewModel);
      viewModel
        ..setWeight('301')
        ..setHeight('99')
        ..setBirthDate(DateTime(2010, 1, 1));

      expect(await viewModel.submit(), isFalse);

      expect(profiles.created, isEmpty);
      expect(viewModel.fieldErrors.keys, {
        ProfileFormViewModel.weightField,
        ProfileFormViewModel.heightField,
        ProfileFormViewModel.birthDateField,
      });
    });

    test('perfil válido: lo crea y marca el perfil completo', () async {
      final viewModel = build(ProfileFormMode.setup);
      fillValidForm(viewModel);

      expect(await viewModel.submit(), isTrue);

      expect(profiles.created.single, testProfile);
      expect(auth.markProfileCompletedCalls, 1);
      expect(auth.currentUser?.profileCompleted, isTrue);
    });

    test('si el perfil ya existía (409) también continúa', () async {
      profiles.stored = testProfile;
      final viewModel = build(ProfileFormMode.setup);
      fillValidForm(viewModel);

      expect(await viewModel.submit(), isTrue);

      expect(auth.markProfileCompletedCalls, 1);
      expect(viewModel.generalError, isNull);
    });

    test('errores por campo del backend se muestran en su campo', () async {
      profiles.createError = apiError(
        ApiErrorCode.validation,
        fields: {'weight_kg': 'El peso debe estar entre 30 y 300 kg'},
      );
      final viewModel = build(ProfileFormMode.setup);
      fillValidForm(viewModel);

      expect(await viewModel.submit(), isFalse);

      expect(
        viewModel.fieldError(ProfileFormViewModel.weightField),
        'El peso debe estar entre 30 y 300 kg',
      );
      expect(auth.markProfileCompletedCalls, 0);
    });

    test('sin red muestra un error general y no marca el perfil', () async {
      profiles.createError = networkError;
      final viewModel = build(ProfileFormMode.setup);
      fillValidForm(viewModel);

      expect(await viewModel.submit(), isFalse);

      expect(viewModel.generalError, networkError.message);
      expect(auth.currentUser?.profileCompleted, isFalse);
      expect(viewModel.isSubmitting, isFalse);
    });

    test('editar un campo limpia su error', () async {
      final viewModel = build(ProfileFormMode.setup);
      await viewModel.submit();

      viewModel.setWeight('70');

      expect(viewModel.fieldError(ProfileFormViewModel.weightField), isNull);
      expect(viewModel.fieldError(ProfileFormViewModel.heightField), isNotNull);
    });

    test('cerrar sesión desde el formulario', () async {
      final viewModel = build(ProfileFormMode.setup);

      await viewModel.logout();

      expect(auth.logoutCalls, 1);
      expect(auth.state, isA<Unauthenticated>());
    });
  });

  group('edición (Mi perfil)', () {
    setUp(() {
      auth = FakeAuthRepository(initialState: const Authenticated(testUser));
      profiles = FakeProfileRepository(stored: testProfile);
    });

    test('carga el perfil guardado en el formulario', () async {
      final viewModel = build(ProfileFormMode.edit);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.objective, Objective.loseFat);
      expect(viewModel.level, ExperienceLevel.beginner);
      expect(viewModel.trainingDays, 4);
      expect(viewModel.weight, '72.5');
      expect(viewModel.height, '170');
      expect(viewModel.gender, Gender.female);
      expect(viewModel.birthDate, DateTime(1996, 5, 20));
    });

    test('si no puede cargar, muestra el error para reintentar', () async {
      profiles.getError = networkError;
      final viewModel = build(ProfileFormMode.edit);

      await viewModel.load();

      expect(viewModel.loadError, networkError.message);

      profiles.getError = null;
      await viewModel.load();
      expect(viewModel.loadError, isNull);
      expect(viewModel.objective, Objective.loseFat);
    });

    test('guarda los cambios con PATCH y no toca la sesión', () async {
      final viewModel = build(ProfileFormMode.edit);
      await viewModel.load();

      viewModel
        ..setWeight('70.2')
        ..setObjective(Objective.gainMuscle)
        ..setTrainingDays(5);

      expect(await viewModel.submit(), isTrue);

      final saved = profiles.updated.single;
      expect(saved.weightKg, 70.2);
      expect(saved.objective, Objective.gainMuscle);
      expect(saved.trainingDays, 5);
      expect(saved.heightCm, 170);
      expect(profiles.created, isEmpty);
      expect(auth.markProfileCompletedCalls, 0);
    });
  });
}
