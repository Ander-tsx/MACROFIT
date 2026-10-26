import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/app.dart';
import 'package:macrofit_app/app/dependencies.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/presentation/login/login_view.dart';
import 'package:macrofit_app/features/auth/presentation/register/register_view.dart';
import 'package:macrofit_app/features/auth/presentation/splash/splash_view.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_meal.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/clients/presentation/client_detail/client_detail_view.dart';
import 'package:macrofit_app/features/clients/presentation/client_meals/client_meals_view.dart';
import 'package:macrofit_app/features/clients/presentation/clients_list/clients_list_view.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/goals/presentation/coach_goal_form/coach_goal_form_view.dart';
import 'package:macrofit_app/features/home/presentation/coach_home_view.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view.dart';
import 'package:macrofit_app/features/invite_code/presentation/invite_code/invite_code_view.dart';
import 'package:macrofit_app/features/legal/presentation/privacy_notice/privacy_notice_view.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_photo.dart';
import 'package:macrofit_app/features/meals/domain/entities/photo_pick_exception.dart';
import 'package:macrofit_app/features/meals/presentation/meal_estimate/meal_estimate_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_estimate/meal_estimate_view_model.dart';
import 'package:macrofit_app/features/meals/presentation/meal_photo/meal_photo_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_photo/meal_photo_view_model.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/presentation/profile_form/profile_form_view.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeLegalRepository legal;
  late FakeProfileRepository profiles;
  late FakeGoalsRepository goals;
  late FakeCoachGoalsRepository coachGoals;
  late FakeMealPhotoRepository mealPhotos;
  late FakeMealsRepository meals;
  late FakeClientsRepository clients;
  late FakeInviteCodeRepository inviteCodes;
  late FakeShareService share;

  Future<void> pumpApp(
    WidgetTester tester, {
    AuthState state = const Unauthenticated(),
    bool settle = true,
    Profile? storedProfile,
    PickedPhoto? recoveredPhoto,
    FakeGoalsRepository? goalsRepository,
    List<ClientSummary>? clientList,
    ApiException? clientsError,
    Map<DateTime, List<ClientMeal>>? clientMeals,
    ApiException? mealsError,
    ApiException? inviteCodeError,
  }) async {
    auth = FakeAuthRepository(initialState: state);
    legal = FakeLegalRepository();
    profiles = FakeProfileRepository(stored: storedProfile);
    goals = goalsRepository ?? FakeGoalsRepository();
    coachGoals = FakeCoachGoalsRepository();
    mealPhotos = FakeMealPhotoRepository(recovered: recoveredPhoto);
    meals = FakeMealsRepository();
    clients = FakeClientsRepository(clients: clientList, meals: clientMeals)
      ..error = clientsError
      ..mealsError = mealsError;
    inviteCodes = FakeInviteCodeRepository()..error = inviteCodeError;
    share = FakeShareService();
    await tester.pumpWidget(
      MacroFitApp(
        dependencies: AppDependencies(
          authRepository: auth,
          legalRepository: legal,
          profileRepository: profiles,
          goalsRepository: goals,
          coachGoalsRepository: coachGoals,
          mealPhotoRepository: mealPhotos,
          mealsRepository: meals,
          clientsRepository: clients,
          inviteCodeRepository: inviteCodes,
          shareService: share,
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
      await tester.tap(find.byKey(const Key('client_detail_goals')));
      await tester.pumpAndSettle();
    }

    testWidgets('el coach llega al formulario de un cliente desde su detalle', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testCoach));

      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientsListView), findsOneWidget);
      expect(find.text(testClient.name), findsOneWidget);

      await tester.tap(find.byKey(Key('client_${testClient.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientDetailView), findsOneWidget);

      await tester.tap(find.byKey(const Key('client_detail_goals')));
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

  group('foto de la comida (HU-06)', () {
    Future<void> openMealPhoto(WidgetTester tester) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('"Registrar comida" abre la pantalla de la foto', (
      tester,
    ) async {
      await openMealPhoto(tester);

      expect(find.byType(MealPhotoView), findsOneWidget);
      expect(find.byKey(const Key('meal_photo_camera')), findsOneWidget);
      expect(find.byKey(const Key('meal_photo_gallery')), findsOneWidget);
      expect(find.byKey(const Key('meal_photo_upload')), findsNothing);
    });

    testWidgets('elige de la galería, muestra la vista previa y la sube', (
      tester,
    ) async {
      await openMealPhoto(tester);

      await tester.tap(find.byKey(const Key('meal_photo_gallery')));
      await tester.pumpAndSettle();
      expect(mealPhotos.picks, [PhotoSource.gallery]);
      expect(find.byKey(const Key('meal_photo_preview')), findsOneWidget);

      await tester.tap(find.byKey(const Key('meal_photo_upload')));
      await tester.pumpAndSettle();
      expect(mealPhotos.uploads.single, testPhoto);
      // HU-07: la foto subida pasa directo a la estimación.
      expect(find.byType(MealPhotoView), findsNothing);
      expect(find.byType(MealEstimateView), findsOneWidget);
    });

    testWidgets('con el permiso de cámara negado explica y ofrece la galería', (
      tester,
    ) async {
      await openMealPhoto(tester);
      mealPhotos.pickError = const PhotoPickException(
        PhotoPickError.cameraDenied,
      );

      await tester.tap(find.byKey(const Key('meal_photo_camera')));
      await tester.pumpAndSettle();

      expect(find.text(MealPhotoViewModel.cameraDeniedMessage), findsOneWidget);
      expect(find.byKey(const Key('meal_photo_gallery')), findsOneWidget);
    });

    testWidgets(
      'si Android cerró la app con la cámara abierta vuelve a la vista previa',
      (tester) async {
        await pumpApp(
          tester,
          state: const Authenticated(testUser),
          recoveredPhoto: testPhoto,
        );

        expect(find.byType(MealPhotoView), findsOneWidget);
        expect(find.byKey(const Key('meal_photo_preview')), findsOneWidget);
        expect(find.byKey(const Key('meal_photo_upload')), findsOneWidget);
        expect(mealPhotos.hasRecoveredPhoto, isFalse);

        // El inicio queda debajo: atrás regresa a él y no vuelve a redirigir.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(UserHomeView), findsOneWidget);
      },
    );

    testWidgets('un coach no ve el acceso a registrar comida', (tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      expect(find.byKey(const Key('register_meal_button')), findsNothing);
    });
  });

  group('estimación nutricional (HU-07)', () {
    /// Inicio → Registrar comida → galería → Usar esta foto.
    Future<void> uploadPhoto(
      WidgetTester tester, {
      ApiException? estimateError,
      Completer<void>? estimateGate,
      bool settle = true,
    }) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      meals
        ..estimateError = estimateError
        ..estimateGate = estimateGate;
      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meal_photo_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meal_photo_upload')));
      settle ? await tester.pumpAndSettle() : await tester.pump();
    }

    testWidgets(
      'al usar la foto estima con su id, muestra la carga y después el resultado',
      (tester) async {
        await uploadPhoto(
          tester,
          estimateGate: Completer<void>(),
          settle: false,
        );
        await tester.pump();

        expect(meals.estimates, [testUploadedPhoto.id]);
        expect(find.byKey(const Key('meal_estimate_loading')), findsOneWidget);
        expect(find.byKey(const Key('meal_estimate_photo')), findsOneWidget);

        meals.estimateGate!.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('meal_estimate_loading')), findsNothing);
        expect(find.text('Arroz blanco cocido'), findsOneWidget);
        expect(find.text('150 g'), findsOneWidget);
        expect(find.text('Pechuga de pollo a la plancha'), findsOneWidget);
        expect(
          find.text('195\u00a0kcal · P\u00a04\u00a0g · G\u00a00.4\u00a0g'),
          findsOneWidget,
        );
        expect(find.text('413 kcal'), findsOneWidget);
        expect(find.text('42.2 g'), findsOneWidget);
        expect(find.text('4.9 g'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('meal_estimate_continue')),
          200,
        );
        expect(find.byKey(const Key('meal_estimate_continue')), findsOneWidget);
      },
    );

    testWidgets('el resultado muestra la leyenda de estimación (RNF-07)', (
      tester,
    ) async {
      await uploadPhoto(tester);

      expect(find.text(MealEstimateViewModel.disclaimer), findsOneWidget);
    });

    testWidgets('comida no reconocida ofrece solo capturar a mano', (
      tester,
    ) async {
      await uploadPhoto(
        tester,
        estimateError: apiError(ApiErrorCode.foodNotRecognized, status: 422),
      );

      expect(
        find.text(MealEstimateViewModel.notRecognizedMessage),
        findsOneWidget,
      );
      expect(find.byKey(const Key('meal_estimate_manual')), findsOneWidget);
      expect(find.byKey(const Key('meal_estimate_retry')), findsNothing);
    });

    testWidgets('sin conexión ofrece reintentar sin cerrar la pantalla', (
      tester,
    ) async {
      await uploadPhoto(tester, estimateError: networkError);

      expect(find.text(networkError.message), findsOneWidget);
      expect(find.byKey(const Key('meal_estimate_manual')), findsOneWidget);

      meals.estimateError = null;
      await tester.tap(find.byKey(const Key('meal_estimate_retry')));
      await tester.pumpAndSettle();

      expect(meals.estimates, hasLength(2));
      expect(find.byType(MealEstimateView), findsOneWidget);
      expect(find.text('Arroz blanco cocido'), findsOneWidget);
    });

    testWidgets('atrás regresa al inicio, no a la foto ya subida', (
      tester,
    ) async {
      await uploadPhoto(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(UserHomeView), findsOneWidget);
    });
  });

  group('lista de clientes (HU-24)', () {
    Future<void> openClients(
      WidgetTester tester, {
      List<ClientSummary>? clientList,
      ApiException? clientsError,
    }) async {
      await pumpApp(
        tester,
        state: const Authenticated(testCoach),
        clientList: clientList,
        clientsError: clientsError,
      );
      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra nombre, meta y último registro de cada cliente', (
      tester,
    ) async {
      await openClients(tester);

      expect(find.byType(ClientsListView), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('2200 kcal · P 160 g · G 70 g'), findsOneWidget);
      expect(find.textContaining('Meta del coach'), findsOneWidget);
      expect(find.textContaining('Último registro:'), findsOneWidget);
      expect(find.text('José Pérez'), findsOneWidget);
      expect(find.text('Sin meta'), findsOneWidget);
      expect(find.textContaining('Sin registros'), findsOneWidget);
    });

    testWidgets('la búsqueda filtra por nombre sin otra petición', (
      tester,
    ) async {
      await openClients(tester);

      await tester.enterText(find.byKey(const Key('clients_search')), 'JOSE');
      await tester.pumpAndSettle();
      expect(find.text('José Pérez'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);

      await tester.enterText(find.byKey(const Key('clients_search')), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.text('Ningún cliente coincide con la búsqueda.'),
        findsOneWidget,
      );
      expect(clients.calls, 1);
    });

    testWidgets('sin clientes invita a compartir el código de invitación', (
      tester,
    ) async {
      await openClients(tester, clientList: []);

      expect(find.byKey(const Key('clients_empty')), findsOneWidget);
      expect(find.byKey(const Key('clients_search')), findsNothing);

      // HU-12: desde la lista vacía se llega al código para compartirlo.
      final callsBefore = clients.calls;
      await tester.tap(find.byKey(const Key('clients_invite_code')));
      await tester.pumpAndSettle();
      expect(find.byType(InviteCodeView), findsOneWidget);
      expect(find.text(testInviteCode), findsOneWidget);

      // Atrás regresa a la lista vacía, que no se recarga sola.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(InviteCodeView), findsNothing);
      expect(find.byKey(const Key('clients_empty')), findsOneWidget);
      expect(clients.calls, callsBefore);
    });

    testWidgets('un error al cargar permite reintentar', (tester) async {
      await openClients(tester, clientsError: networkError);
      expect(find.text(networkError.message), findsOneWidget);

      clients.error = null;
      await tester.tap(find.byKey(const Key('clients_retry')));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('el detalle da acceso a las metas y a las comidas', (
      tester,
    ) async {
      await openClients(tester);

      await tester.tap(find.byKey(Key('client_${testClientSummary.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(ClientDetailView), findsOneWidget);
      expect(find.text('ana@macrofit.test'), findsOneWidget);
      expect(find.text('2200 kcal · P 160 g · G 70 g'), findsOneWidget);
      expect(find.byKey(const Key('client_detail_goals')), findsOneWidget);
      final meals = tester.widget<ListTile>(
        find.byKey(const Key('client_detail_meals')),
      );
      expect(meals.enabled, isTrue);
    });
  });

  group('comidas de un cliente (HU-25)', () {
    final today = dayOf(DateTime.now());
    final photoMeal = testMealWithPhoto(
      eatenAt: today.add(const Duration(hours: 14, minutes: 5)),
    );
    final manualMeal = testManualMeal(
      eatenAt: today.add(const Duration(hours: 19, minutes: 30)),
    );

    Future<void> openMeals(
      WidgetTester tester, {
      Map<DateTime, List<ClientMeal>>? clientMeals,
      ApiException? mealsError,
    }) async {
      await pumpApp(
        tester,
        state: const Authenticated(testCoach),
        clientMeals: clientMeals,
        mealsError: mealsError,
      );
      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('client_${testClientSummary.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('client_detail_meals')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'desde el detalle se abren las comidas del día con hora, foto y valores',
      (tester) async {
        await openMeals(
          tester,
          clientMeals: {
            today: [photoMeal, manualMeal],
          },
        );

        expect(find.byType(ClientMealsView), findsOneWidget);
        expect(find.text('Hoy'), findsOneWidget);
        expect(find.text('14:05'), findsOneWidget);
        expect(find.text('19:30'), findsOneWidget);
        expect(find.text('413 kcal · P 42.2 g · G 4.9 g'), findsOneWidget);
        expect(find.text('380 kcal · P 40 g · G 6.5 g'), findsOneWidget);
        expect(
          find.text('Total del día: 793 kcal · P 82.2 g · G 11.4 g'),
          findsOneWidget,
        );
        expect(find.byKey(Key('meal_${photoMeal.id}_photo')), findsOneWidget);
        expect(find.byKey(Key('meal_${manualMeal.id}_manual')), findsOneWidget);
        expect(clients.photoRequests, [photoMeal.photoUrl]);
      },
    );

    testWidgets('es de solo lectura', (tester) async {
      await openMeals(
        tester,
        clientMeals: {
          today: [photoMeal, manualMeal],
        },
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('un día sin registros lo indica y permite elegir otra fecha', (
      tester,
    ) async {
      await openMeals(tester);

      expect(find.text('No hay registros este día.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('client_meals_pick_date')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('el coach cambia al día anterior', (tester) async {
      await openMeals(tester);

      await tester.tap(find.byKey(const Key('client_meals_prev')));
      await tester.pumpAndSettle();

      expect(find.text('Ayer'), findsOneWidget);
      expect(
        clients.mealRequests.last.date,
        DateTime(today.year, today.month, today.day - 1),
      );
    });

    testWidgets('un cliente desvinculado lo indica y regresa a la lista', (
      tester,
    ) async {
      await openMeals(
        tester,
        mealsError: apiError(ApiErrorCode.clientNotLinked, status: 403),
      );

      expect(
        find.text('Este cliente ya no está vinculado contigo.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('client_meals_back')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientsListView), findsOneWidget);
      expect(find.byType(ClientDetailView), findsNothing);
    });

    testWidgets('sin conexión muestra el error y permite reintentar', (
      tester,
    ) async {
      await openMeals(
        tester,
        clientMeals: {
          today: [manualMeal],
        },
        mealsError: networkError,
      );
      expect(find.text(networkError.message), findsOneWidget);

      clients.mealsError = null;
      await tester.tap(find.byKey(const Key('client_meals_retry')));
      await tester.pumpAndSettle();
      expect(find.text('19:30'), findsOneWidget);
    });
  });

  group('código de invitación (HU-12)', () {
    Future<void> openInviteCode(
      WidgetTester tester, {
      ApiException? inviteCodeError,
    }) async {
      await pumpApp(
        tester,
        state: const Authenticated(testCoach),
        inviteCodeError: inviteCodeError,
      );
      await tester.tap(find.byKey(const Key('invite_code_home_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('el coach ve su código desde su pantalla principal', (
      tester,
    ) async {
      await openInviteCode(tester);

      expect(find.byType(InviteCodeView), findsOneWidget);
      expect(find.text(testInviteCode), findsOneWidget);
      expect(inviteCodes.getCalls, 1);
    });

    testWidgets('también se abre desde la barra del panel', (tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      await tester.tap(find.byKey(const Key('invite_code_button')));
      await tester.pumpAndSettle();

      expect(find.byType(InviteCodeView), findsOneWidget);
    });

    testWidgets('copiar pone el código en el portapapeles y lo avisa', (
      tester,
    ) async {
      await openInviteCode(tester);

      await tester.tap(find.byKey(const Key('invite_code_copy')));
      await tester.pumpAndSettle();

      expect(share.copied, [testInviteCode]);
      expect(find.text('Código copiado al portapapeles'), findsOneWidget);
    });

    testWidgets('compartir abre la hoja con un mensaje que incluye el código', (
      tester,
    ) async {
      await openInviteCode(tester);

      await tester.tap(find.byKey(const Key('invite_code_share')));
      await tester.pumpAndSettle();

      final sent = share.shared.single;
      expect(sent.text, contains(testInviteCode));
      expect(sent.origin, isNotNull);
    });

    testWidgets('regenerar pide confirmación y muestra el código nuevo', (
      tester,
    ) async {
      await openInviteCode(tester);

      await tester.tap(find.byKey(const Key('invite_code_regenerate')));
      await tester.pumpAndSettle();
      expect(find.textContaining('dejará de funcionar'), findsOneWidget);
      expect(inviteCodes.regenerateCalls, 0);

      await tester.tap(find.byKey(const Key('invite_code_regenerate_confirm')));
      await tester.pumpAndSettle();

      expect(inviteCodes.regenerateCalls, 1);
      expect(find.text('N3W8CD'), findsOneWidget);
      expect(find.text(testInviteCode), findsNothing);
      expect(find.textContaining('El anterior ya no funciona'), findsOneWidget);
    });

    testWidgets('cancelar la regeneración conserva el código', (tester) async {
      await openInviteCode(tester);

      await tester.tap(find.byKey(const Key('invite_code_regenerate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite_code_regenerate_cancel')));
      await tester.pumpAndSettle();

      expect(inviteCodes.regenerateCalls, 0);
      expect(find.text(testInviteCode), findsOneWidget);
    });

    testWidgets('sin conexión muestra el error y permite reintentar', (
      tester,
    ) async {
      await openInviteCode(tester, inviteCodeError: networkError);
      expect(find.text(networkError.message), findsOneWidget);
      expect(find.byKey(const Key('invite_code_copy')), findsNothing);

      inviteCodes.error = null;
      await tester.tap(find.byKey(const Key('invite_code_retry')));
      await tester.pumpAndSettle();
      expect(find.text(testInviteCode), findsOneWidget);
    });
  });

  group('meta vigente en la pantalla principal (HU-26)', () {
    testWidgets('muestra la meta calculada con su origen', (tester) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        goalsRepository: FakeGoalsRepository(
          current: testGoal(
            calories: 1900,
            proteinG: 130,
            fatG: 60,
            source: GoalSource.system,
          ),
        ),
      );

      expect(find.byType(UserHomeView), findsOneWidget);
      expect(find.text('1900 kcal'), findsOneWidget);
      expect(find.text('130 g'), findsOneWidget);
      expect(find.text('60 g'), findsOneWidget);
      expect(find.text('Calculada'), findsOneWidget);
      expect(goals.currentCalls, 1);
    });

    testWidgets('indica cuando la meta la definió el coach', (tester) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        goalsRepository: FakeGoalsRepository(
          current: testGoal(source: GoalSource.coach),
        ),
      );

      expect(find.text('2200 kcal'), findsOneWidget);
      expect(find.text('Definida por tu coach'), findsOneWidget);
    });

    testWidgets('sin meta muestra un mensaje y no un error', (tester) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        goalsRepository: FakeGoalsRepository.withoutGoal(),
      );

      expect(find.byKey(const Key('home_goal_empty')), findsOneWidget);
      expect(find.byKey(const Key('home_goal_retry')), findsNothing);
    });

    testWidgets('sin conexión muestra el error y reintenta', (tester) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        goalsRepository: FakeGoalsRepository()..error = networkError,
      );

      expect(find.text(networkError.message), findsOneWidget);
      goals.error = null;
      await tester.tap(find.byKey(const Key('home_goal_retry')));
      await tester.pumpAndSettle();

      expect(find.text(networkError.message), findsNothing);
      expect(find.text('2200 kcal'), findsOneWidget);
      expect(goals.currentCalls, 2);
    });

    testWidgets('al regresar de Mi perfil se vuelve a consultar la meta', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        storedProfile: testProfile,
      );
      expect(find.text('2200 kcal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_button')));
      await tester.pumpAndSettle();
      // El backend recalcula la meta al cambiar el peso (HU-04).
      goals.current = testGoal(calories: 2050, source: GoalSource.system);
      await tester.enterText(find.byKey(const Key('profile_weight')), '70');
      await tester.ensureVisible(find.byKey(const Key('profile_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_submit')));
      await tester.pumpAndSettle();

      expect(find.byType(UserHomeView), findsOneWidget);
      expect(find.text('2050 kcal'), findsOneWidget);
      expect(goals.currentCalls, 2);
    });
  });
}
