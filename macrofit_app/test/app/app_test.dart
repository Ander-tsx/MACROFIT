import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/app.dart';
import 'package:macrofit_app/app/dependencies.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/presentation/login/login_view.dart';
import 'package:macrofit_app/features/auth/presentation/register/register_view.dart';
import 'package:macrofit_app/features/auth/presentation/splash/splash_view.dart';
import 'package:macrofit_app/features/goals/presentation/coach_clients/coach_clients_view.dart';
import 'package:macrofit_app/features/goals/presentation/coach_goal_form/coach_goal_form_view.dart';
import 'package:macrofit_app/features/home/presentation/coach_home_view.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view.dart';
import 'package:macrofit_app/features/legal/presentation/privacy_notice/privacy_notice_view.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/presentation/profile_form/profile_form_view.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeLegalRepository legal;
  late FakeProfileRepository profiles;
  late FakeCoachGoalsRepository coachGoals;

  Future<void> pumpApp(
    WidgetTester tester, {
    AuthState state = const Unauthenticated(),
    bool settle = true,
    Profile? storedProfile,
  }) async {
    auth = FakeAuthRepository(initialState: state);
    legal = FakeLegalRepository();
    profiles = FakeProfileRepository(stored: storedProfile);
    coachGoals = FakeCoachGoalsRepository();
    await tester.pumpWidget(
      MacroFitApp(
        dependencies: AppDependencies(
          authRepository: auth,
          legalRepository: legal,
          profileRepository: profiles,
          coachGoalsRepository: coachGoals,
        ),
      ),
    );
    // La carga inicial tiene una animación infinita: ahí no se espera a que termine.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  testWidgets('mientras se lee la sesión muestra la carga inicial', (
    tester,
  ) async {
    await pumpApp(tester, state: const AuthUnknown(), settle: false);
    expect(find.byType(SplashView), findsOneWidget);
  });

  testWidgets('sin sesión abre el inicio de sesión', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('el login de un coach lleva a la pantalla de coach', (
    tester,
  ) async {
    await pumpApp(tester);
    auth.loginRole = testCoach.role;

    await tester.enterText(
      find.byKey(const Key('login_email')),
      testCoach.email,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login_password')),
        matching: find.byType(TextField),
      ),
      'Segura123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(CoachHomeView), findsOneWidget);
    expect(find.text('Hola, ${testCoach.name}'), findsOneWidget);
  });

  testWidgets('registro vacío no se envía y muestra qué falta', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('¿No tienes cuenta? Crea una'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterView), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(auth.registrations, isEmpty);
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('Debes elegir un rol'), findsOneWidget);
    expect(find.text('Debes aceptar el aviso de privacidad'), findsOneWidget);
  });

  testWidgets('el enlace del registro abre el aviso completo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('¿No tienes cuenta? Crea una'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('register_privacy_link')));
    await tester.tap(find.byKey(const Key('register_privacy_link')));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyNoticeView), findsOneWidget);
    expect(find.textContaining('Aviso de privacidad integral'), findsOneWidget);
  });

  testWidgets('cerrar sesión vuelve al login y atrás no regresa', (
    tester,
  ) async {
    await pumpApp(tester, state: const Authenticated(testUser));
    expect(find.byType(UserHomeView), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(LoginView), findsOneWidget);

    // Botón atrás del sistema: no hay pantalla protegida a la cual regresar.
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isFalse);
    expect(find.byType(UserHomeView), findsNothing);
  });

  group('perfil inicial (HU-03)', () {
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('un usuario sin perfil va al formulario tras iniciar sesión', (
      tester,
    ) async {
      await pumpApp(tester);
      auth.loginUser = testNewUser;

      await tester.enterText(
        find.byKey(const Key('login_email')),
        testNewUser.email,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('login_password')),
          matching: find.byType(TextField),
        ),
        'Segura123',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileFormView), findsOneWidget);
      expect(find.text('Tu perfil inicial'), findsOneWidget);
      expect(find.byType(UserHomeView), findsNothing);
    });

    testWidgets('sin completar el perfil no se puede llegar al inicio', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testNewUser));
      expect(find.byType(ProfileFormView), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('profile_submit')));

      expect(profiles.created, isEmpty);
      expect(find.text('Elige tu objetivo'), findsOneWidget);
      expect(find.text('El peso es obligatorio'), findsOneWidget);
      expect(find.byType(ProfileFormView), findsOneWidget);

      // El botón atrás no lleva a la pantalla principal.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UserHomeView), findsNothing);
    });

    testWidgets('al guardar un perfil válido entra a la pantalla principal', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testNewUser));

      await tapVisible(tester, find.text(Objective.gainMuscle.label));
      await tapVisible(tester, find.text(ExperienceLevel.advanced.label));
      await tapVisible(
        tester,
        find.byKey(const Key('profile_training_days_5')),
      );
      await tester.enterText(find.byKey(const Key('profile_weight')), '80,5');
      await tester.enterText(find.byKey(const Key('profile_height')), '178');
      await tapVisible(tester, find.text(Gender.male.label));

      // Selector de fecha: el valor por defecto (hace 25 años) es válido.
      await tapVisible(tester, find.byKey(const Key('profile_birth_date')));
      final okLabel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(okLabel));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('profile_submit')));

      expect(profiles.created, hasLength(1));
      final saved = profiles.created.single;
      expect(saved.objective, Objective.gainMuscle);
      expect(saved.level, ExperienceLevel.advanced);
      expect(saved.trainingDays, 5);
      expect(saved.weightKg, 80.5);
      expect(saved.heightCm, 178);
      expect(saved.gender, Gender.male);
      expect(auth.markProfileCompletedCalls, 1);
      expect(find.byType(UserHomeView), findsOneWidget);
    });

    testWidgets('un coach entra a su pantalla sin ver el formulario', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      expect(find.byType(CoachHomeView), findsOneWidget);
      expect(find.byType(ProfileFormView), findsNothing);
      expect(profiles.getCalls, 0);
    });

    testWidgets('Mi perfil carga los datos guardados y guarda los cambios', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        storedProfile: testProfile,
      );

      await tester.tap(find.byKey(const Key('profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(profiles.getCalls, 1);
      expect(find.text('72.5'), findsOneWidget);
      expect(find.text('170'), findsOneWidget);
      expect(find.text('20/05/1996'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('profile_weight')), '70');
      await tapVisible(tester, find.byKey(const Key('profile_submit')));

      expect(profiles.updated.single.weightKg, 70);
      expect(profiles.stored!.weightKg, 70);
      expect(find.byType(UserHomeView), findsOneWidget);

      // Al volver a abrir "Mi perfil" se ve el cambio (se consulta de nuevo).
      await tester.tap(find.byKey(const Key('profile_button')));
      await tester.pumpAndSettle();
      expect(profiles.getCalls, 2);
      expect(find.text('70'), findsOneWidget);
    });
  });

  group('metas por coach (HU-05)', () {
    Future<void> openClientForm(WidgetTester tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('client_${testClient.id}')));
      await tester.pumpAndSettle();
    }

    testWidgets('el coach llega al formulario de un cliente en dos pantallas', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testCoach));

      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      expect(find.byType(CoachClientsView), findsOneWidget);
      expect(find.text(testClient.name), findsOneWidget);

      await tester.tap(find.byKey(Key('client_${testClient.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(CoachGoalFormView), findsOneWidget);
    });

    testWidgets('guarda la meta y la muestra en el historial', (tester) async {
      await openClientForm(tester);
      expect(find.text('Este cliente todavía no tiene metas.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('goal_calories')), '2200');
      await tester.enterText(find.byKey(const Key('goal_protein')), '160');
      await tester.enterText(find.byKey(const Key('goal_fat')), '70');
      await tester.tap(find.byKey(const Key('goal_submit')));
      await tester.pumpAndSettle();

      expect(coachGoals.saved.single.clientId, testClient.id);
      expect(find.text('Meta guardada'), findsOneWidget);
      expect(find.text('2200 kcal · P 160 g · G 70 g'), findsOneWidget);
    });

    testWidgets('un formulario vacío no se envía y señala los campos', (
      tester,
    ) async {
      await openClientForm(tester);

      await tester.tap(find.byKey(const Key('goal_submit')));
      await tester.pumpAndSettle();

      expect(coachGoals.saved, isEmpty);
      expect(find.text('Las calorías son obligatorias'), findsOneWidget);
      expect(find.text('La proteína es obligatoria'), findsOneWidget);
      expect(find.text('La grasa es obligatoria'), findsOneWidget);
    });

    testWidgets('un usuario no ve el acceso a clientes', (tester) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      expect(find.byKey(const Key('clients_button')), findsNothing);
    });
  });
}
