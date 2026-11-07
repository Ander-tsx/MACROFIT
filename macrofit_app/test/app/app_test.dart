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
import 'package:macrofit_app/core/presentation/theme/lucide_icons.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_meal.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/clients/presentation/client_detail/client_detail_view.dart';
import 'package:macrofit_app/features/clients/presentation/client_meals/client_meals_view.dart';
import 'package:macrofit_app/features/clients/presentation/client_progress/client_progress_view.dart';
import 'package:macrofit_app/features/clients/presentation/clients_list/clients_list_view.dart';
import 'package:macrofit_app/features/goals/domain/entities/nutritional_goal.dart';
import 'package:macrofit_app/features/goals/presentation/coach_goal_form/coach_goal_form_view.dart';
import 'package:macrofit_app/features/home/presentation/coach_home_view.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view.dart';
import 'package:macrofit_app/features/invite_code/presentation/invite_code/invite_code_view.dart';
import 'package:macrofit_app/features/legal/presentation/privacy_notice/privacy_notice_view.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_estimate.dart';
import 'package:macrofit_app/features/meals/domain/entities/meal_photo.dart';
import 'package:macrofit_app/features/meals/domain/entities/photo_pick_exception.dart';
import 'package:macrofit_app/features/meals/presentation/meal_estimate/meal_estimate_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_estimate/meal_estimate_view_model.dart';
import 'package:macrofit_app/features/meals/presentation/meal_form/meal_form_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_history/meal_history_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_history/meal_history_view_model.dart';
import 'package:macrofit_app/features/meals/presentation/meal_photo/meal_photo_view.dart';
import 'package:macrofit_app/features/meals/presentation/meal_photo/meal_photo_view_model.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/presentation/profile_form/profile_form_view.dart';
import 'package:macrofit_app/features/summary/domain/entities/macro_values.dart';
import 'package:macrofit_app/features/summary/domain/usecases/app_day.dart';
import 'package:macrofit_app/features/summary/presentation/weekly_summary/weekly_summary_view.dart';
import 'package:macrofit_app/features/progress/presentation/progress_charts/progress_view.dart';
import 'package:macrofit_app/features/progress/presentation/weights/weights_view.dart';
import 'package:macrofit_app/features/routines/presentation/assign_routine/assign_routine_view.dart';
import 'package:macrofit_app/features/routines/presentation/exercise_picker/exercise_picker_view.dart';
import 'package:macrofit_app/features/routines/presentation/routine_builder/routine_builder_view.dart';
import 'package:macrofit_app/features/routines/presentation/routines_list/routines_list_view.dart';

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
  late FakeCoachLinkRepository coachLinksRepo;
  late FakeWeightsRepository weightsRepo;
  late FakeProgressRepository progress;
  late FakeShareService share;
  late FakeSummaryRepository summary;
  late FakeRoutinesRepository routines;

  Future<void> pumpApp(
    WidgetTester tester, {
    AuthState state = const Unauthenticated(),
    bool settle = true,
    Profile? storedProfile,
    PickedPhoto? recoveredPhoto,
    FakeGoalsRepository? goalsRepository,
    List<ClientSummary>? clientList,
    FakeSummaryRepository? summaryRepository,
    ApiException? clientsError,
    Map<DateTime, List<ClientMeal>>? clientMeals,
    ApiException? mealsError,
    ApiException? inviteCodeError,
    ApiException? routinesError,
  }) async {
    auth = FakeAuthRepository(initialState: state);
    legal = FakeLegalRepository();
    profiles = FakeProfileRepository(stored: storedProfile);
    goals = goalsRepository ?? FakeGoalsRepository();
    coachGoals = FakeCoachGoalsRepository();
    mealPhotos = FakeMealPhotoRepository(recovered: recoveredPhoto);
    meals = FakeMealsRepository();
    summary = summaryRepository ?? FakeSummaryRepository();
    clients = FakeClientsRepository(clients: clientList, meals: clientMeals)
      ..error = clientsError
      ..mealsError = mealsError;
    inviteCodes = FakeInviteCodeRepository()..error = inviteCodeError;
    coachLinksRepo = FakeCoachLinkRepository();
    weightsRepo = FakeWeightsRepository();
    progress = FakeProgressRepository();
    share = FakeShareService();
    routines = FakeRoutinesRepository()..listError = routinesError;
    await tester.pumpWidget(
      MacroFitApp(
        dependencies: AppDependencies(
          summaryRepository: summary,
          authRepository: auth,
          legalRepository: legal,
          profileRepository: profiles,
          goalsRepository: goals,
          coachGoalsRepository: coachGoals,
          mealPhotoRepository: mealPhotos,
          mealsRepository: meals,
          clientsRepository: clients,
          inviteCodeRepository: inviteCodes,
          coachLinkRepository: coachLinksRepo,
          weightsRepository: weightsRepo,
          progressRepository: progress,
          routinesRepository: routines,
          myRoutinesRepository: FakeMyRoutinesRepository(),
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

  group('progreso (HU-22)', () {
    Future<void> openProgress(WidgetTester tester) async {
      // Alto suficiente para construir las tres gráficas.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, state: const Authenticated(testUser));
      await tester.tap(find.byKey(const Key('progress_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra peso, consumo por día y entrenamiento de la semana', (
      tester,
    ) async {
      await openProgress(tester);

      expect(find.byType(ProgressView), findsOneWidget);
      expect(progress.requests, hasLength(1));
      expect(find.byKey(const Key('progress_weight_chart')), findsOneWidget);
      expect(find.text('−0.7 kg en el periodo'), findsOneWidget);
      expect(find.byKey(const Key('progress_chart_calories')), findsOneWidget);
      expect(find.text('Dentro de la meta: 4 de 7 días'), findsOneWidget);
      expect(
        find.byKey(const Key('progress_compliance_chart')),
        findsOneWidget,
      );
      expect(find.text('0 de 4 sesiones en el periodo'), findsOneWidget);
    });

    testWidgets('cambia el macro de la gráfica de consumo', (tester) async {
      await openProgress(tester);

      await tester.tap(find.byKey(const Key('progress_macro_protein')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('progress_chart_protein')), findsOneWidget);
      expect(find.byKey(const Key('progress_chart_calories')), findsNothing);
    });

    testWidgets('cambia a mes y no permite ir a un periodo futuro', (
      tester,
    ) async {
      await openProgress(tester);
      final next = find.byKey(const Key('progress_next'));
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(find.byKey(const Key('progress_range_month')));
      await tester.pumpAndSettle();
      final today = appDay(DateTime.now());
      expect(progress.requests.last, '${today.substring(0, 8)}01..$today');
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(find.byKey(const Key('progress_previous')));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    });

    testWidgets('sin datos suficientes muestra mensajes en lugar de gráficas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, state: const Authenticated(testUser));
      progress.withData = false;
      await tester.tap(find.byKey(const Key('progress_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('progress_weight_empty')), findsOneWidget);
      expect(
        find.byKey(const Key('progress_consumption_empty')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progress_weight_chart')), findsNothing);
    });

    testWidgets('sin conexión muestra el error en español y reintenta', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      progress.error = networkError;
      await tester.tap(find.byKey(const Key('progress_button')));
      await tester.pumpAndSettle();

      expect(find.text(networkError.message), findsOneWidget);
      progress.error = null;
      await tester.tap(find.byKey(const Key('progress_retry')));
      await tester.pumpAndSettle();

      expect(find.text(networkError.message), findsNothing);
      expect(find.byKey(const Key('progress_weight')), findsOneWidget);
    });

    testWidgets('"Registrar" abre el registro de peso', (tester) async {
      await openProgress(tester);

      await tester.tap(find.byKey(const Key('progress_register_weight')));
      await tester.pumpAndSettle();

      expect(find.byType(WeightsView), findsOneWidget);
    });
  });

  group('barra inferior (TEC-17)', () {
    testWidgets('cambia entre pestañas y vuelve al inicio', (tester) async {
      await pumpApp(tester, state: const Authenticated(testUser));

      await tester.tap(find.byKey(const Key('progress_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ProgressView), findsOneWidget);

      await tester.tap(find.byKey(const Key('weekly_summary_button')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklySummaryView), findsOneWidget);
      expect(find.byType(ProgressView), findsNothing);

      await tester.tap(find.byKey(const Key('home_tab')));
      await tester.pumpAndSettle();
      expect(find.byType(UserHomeView), findsOneWidget);
      expect(find.byType(WeeklySummaryView), findsNothing);
    });

    testWidgets('se ve en las pantallas secundarias y no al registrar comida', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        storedProfile: testProfile,
      );

      await tester.tap(find.byKey(const Key('profile_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('meal_history_button')).hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
      expect(find.byType(MealPhotoView), findsOneWidget);
      expect(
        find.byKey(const Key('meal_history_button')).hitTestable(),
        findsNothing,
      );
    });

    testWidgets('el coach cambia a sus clientes y a sus rutinas', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testCoach));

      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientsListView), findsOneWidget);

      await tester.tap(find.byKey(const Key('routines_button')));
      await tester.pumpAndSettle();
      expect(find.byType(RoutinesListView), findsOneWidget);
      expect(find.byType(ClientsListView), findsNothing);
    });
  });

  testWidgets('el coach cierra sesión desde la hoja de su cuenta', (
    tester,
  ) async {
    await pumpApp(tester, state: const Authenticated(testCoach));

    await tester.tap(find.byKey(const Key('account_button')));
    await tester.pumpAndSettle();
    expect(find.text(testCoach.email), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('cerrar sesión vuelve al login y atrás no regresa', (
    tester,
  ) async {
    await pumpApp(
      tester,
      state: const Authenticated(testUser),
      storedProfile: testProfile,
    );
    expect(find.byType(UserHomeView), findsOneWidget);

    // TEC-17: cerrar sesión vive al final de "Mi perfil".
    await tester.tap(find.byKey(const Key('profile_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
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
          find.byKey(const Key('meal_estimate_save')),
          200,
        );
        expect(find.byKey(const Key('meal_estimate_save')), findsOneWidget);
        expect(find.byKey(const Key('meal_estimate_correct')), findsOneWidget);
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

  group('formulario de valores (HU-08)', () {
    /// Inicio → Registrar comida → galería → Usar esta foto → estimación.
    Future<void> openEstimate(
      WidgetTester tester, {
      ApiException? estimateError,
    }) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      meals.estimateError = estimateError;
      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meal_photo_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meal_photo_upload')));
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Key key) async {
      // Los campos de texto también tienen un Scrollable: se usa el de la lista.
      await tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Corregir valores abre el formulario precargado y Guardar registra lo corregido',
      (tester) async {
        await openEstimate(tester);
        await tapVisible(tester, const Key('meal_estimate_correct'));

        expect(find.byType(MealFormView), findsOneWidget);
        expect(find.text('Revisar valores'), findsOneWidget);
        expect(find.text('413'), findsOneWidget);
        expect(find.text('42.2'), findsOneWidget);
        expect(find.text('4.9'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('meal_form_calories_kcal')),
          '380',
        );
        await tapVisible(tester, const Key('meal_form_submit'));

        final meal = meals.created.single;
        expect(meal.photoId, testUploadedPhoto.id);
        expect(meal.values.caloriesKcal, 380);
        expect(meal.values.proteinG, 42.2);
        expect(meal.estimated, testEstimate.totals);
        // HU-09: al guardar se abre el historial del día con el registro nuevo.
        expect(find.byType(MealHistoryView), findsOneWidget);
        expect(find.text('Comida registrada'), findsOneWidget);
      },
    );

    testWidgets(
      'comida no reconocida: Capturar a mano abre el formulario vacío y guarda sin estimated',
      (tester) async {
        await openEstimate(
          tester,
          estimateError: apiError(ApiErrorCode.foodNotRecognized, status: 422),
        );
        await tapVisible(tester, const Key('meal_estimate_manual'));

        expect(find.text('Captura manual'), findsOneWidget);
        expect(find.byKey(const Key('meal_form_photo')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('meal_form_calories_kcal')),
          '520',
        );
        await tester.enterText(
          find.byKey(const Key('meal_form_protein_g')),
          '30',
        );
        await tester.enterText(find.byKey(const Key('meal_form_fat_g')), '18');
        await tapVisible(tester, const Key('meal_form_submit'));

        final meal = meals.created.single;
        expect(meal.photoId, testUploadedPhoto.id);
        expect(meal.estimated, isNull);
        expect(find.byType(MealHistoryView), findsOneWidget);
      },
    );

    testWidgets(
      'Capturar sin foto abre el formulario vacío y guarda sin foto',
      (tester) async {
        await pumpApp(tester, state: const Authenticated(testUser));
        await tester.tap(find.byKey(const Key('register_meal_button')));
        await tester.pumpAndSettle();
        await tapVisible(tester, const Key('meal_photo_manual'));

        expect(find.byType(MealFormView), findsOneWidget);
        expect(find.text('Captura manual'), findsOneWidget);
        expect(find.byKey(const Key('meal_form_photo')), findsNothing);

        await tester.enterText(
          find.byKey(const Key('meal_form_calories_kcal')),
          '250',
        );
        await tester.enterText(
          find.byKey(const Key('meal_form_protein_g')),
          '10',
        );
        await tester.enterText(find.byKey(const Key('meal_form_fat_g')), '8');
        await tapVisible(tester, const Key('meal_form_submit'));

        final meal = meals.created.single;
        expect(meal.photoId, isNull);
        expect(meal.estimated, isNull);
        expect(mealPhotos.uploads, isEmpty);
      },
    );

    testWidgets('la validación local muestra el error junto a cada campo', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
      await tapVisible(tester, const Key('meal_photo_manual'));

      await tester.enterText(
        find.byKey(const Key('meal_form_calories_kcal')),
        '-1',
      );
      await tapVisible(tester, const Key('meal_form_submit'));

      expect(find.text('No puede ser negativo'), findsOneWidget);
      expect(find.text('La proteína es obligatoria'), findsOneWidget);
      expect(meals.created, isEmpty);
      expect(find.byType(MealFormView), findsOneWidget);
    });
  });

  group('historial de comidas (HU-09)', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    Future<void> tapVisible(WidgetTester tester, Key key) async {
      // Los campos de texto también tienen un Scrollable: se usa el de la lista.
      await tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> openHistory(WidgetTester tester) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      meals.days[today] = [
        testMeal(
          id: 'desayuno',
          eatenAt: today.add(const Duration(hours: 8, minutes: 30)),
        ),
        testMeal(
          id: 'comida',
          eatenAt: today.add(const Duration(hours: 14, minutes: 5)),
          withPhoto: false,
          values: const NutritionValues(
            caloriesKcal: 380,
            proteinG: 40,
            fatG: 6.5,
          ),
        ),
      ];
      await tapVisible(tester, const Key('meal_history_button'));
    }

    testWidgets(
      'registro por foto en 4 toques desde el inicio hasta guardar (RNF-09)',
      (tester) async {
        await pumpApp(tester, state: const Authenticated(testUser));
        meals.savedDay = today;
        var taps = 0;
        Future<void> tap(Key key) async {
          taps++;
          await tapVisible(tester, key);
        }

        await tap(const Key('register_meal_button'));
        await tap(const Key('meal_photo_gallery'));
        await tap(const Key('meal_photo_upload'));
        await tap(const Key('meal_estimate_save'));

        expect(taps, 4);
        final meal = meals.created.single;
        expect(meal.photoId, testUploadedPhoto.id);
        expect(meal.values, testEstimate.totals);
        expect(meal.estimated, testEstimate.totals);
        // Regresa al historial del día con el registro nuevo.
        expect(find.byType(MealHistoryView), findsOneWidget);
        expect(find.text('Comida registrada'), findsOneWidget);
        expect(
          find.byKey(const Key('meal_6ad0a1b2c3d4e5f6a7b8c9d0')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'al regresar al inicio después de guardar se actualiza el progreso del día (HU-10)',
      (tester) async {
        await pumpApp(tester, state: const Authenticated(testUser));
        meals.savedDay = today;
        expect(summary.dailyDates, hasLength(1));

        await tapVisible(tester, const Key('register_meal_button'));
        await tapVisible(tester, const Key('meal_photo_gallery'));
        await tapVisible(tester, const Key('meal_photo_upload'));
        await tapVisible(tester, const Key('meal_estimate_save'));
        expect(find.byType(MealHistoryView), findsOneWidget);

        summary.daily = testDaySummary(
          consumed: const MacroValues(
            caloriesKcal: 1500,
            proteinG: 90,
            fatG: 50,
          ),
        );
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();

        expect(find.byType(UserHomeView), findsOneWidget);
        expect(summary.dailyDates.length, greaterThan(1));
        expect(find.text('1500 / 2200 kcal'), findsOneWidget);
      },
    );

    testWidgets(
      'al regresar de Mis comidas se actualiza el progreso del día (HU-10)',
      (tester) async {
        await openHistory(tester);
        final requests = summary.dailyDates.length;

        summary.daily = testDaySummary(
          consumed: const MacroValues(
            caloriesKcal: 1500,
            proteinG: 90,
            fatG: 50,
          ),
        );
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();

        expect(summary.dailyDates.length, greaterThan(requests));
        expect(find.text('1500 / 2200 kcal'), findsOneWidget);
      },
    );

    testWidgets(
      'Mis comidas muestra hora, foto y valores de cada registro del día',
      (tester) async {
        await openHistory(tester);

        expect(find.byType(MealHistoryView), findsOneWidget);
        expect(find.text('Hoy'), findsOneWidget);
        expect(meals.listRequests, [today]);
        expect(find.text('08:30'), findsOneWidget);
        expect(find.text('14:05'), findsOneWidget);
        expect(find.byKey(const Key('meal_desayuno_photo')), findsOneWidget);
        expect(find.byKey(const Key('meal_comida_manual')), findsOneWidget);
        expect(find.text('Captura manual'), findsOneWidget);
        expect(find.text('380 kcal · P 40 g · G 6.5 g'), findsOneWidget);
        expect(
          find.text('Total del día: 793 kcal · P 82.2 g · G 11.4 g'),
          findsOneWidget,
        );
        expect(meals.photoRequests, ['foto-desayuno']);
      },
    );

    testWidgets('un día sin registros lo indica y se puede cambiar de día', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      meals.days[yesterday] = [
        testMeal(id: 'cena', eatenAt: yesterday.add(const Duration(hours: 20))),
      ];
      await tapVisible(tester, const Key('meal_history_button'));

      expect(find.byKey(const Key('meal_history_empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('meal_history_prev')));
      await tester.pumpAndSettle();

      expect(find.text('Ayer'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.byKey(const Key('meal_history_empty')), findsNothing);
    });

    testWidgets(
      'eliminar pide confirmación: cancelar lo conserva y confirmar lo quita',
      (tester) async {
        await openHistory(tester);

        await tester.tap(find.byKey(const Key('meal_desayuno_delete')));
        await tester.pumpAndSettle();
        expect(find.text('¿Eliminar este registro?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('meal_delete_cancel')));
        await tester.pumpAndSettle();
        expect(meals.deleted, isEmpty);
        expect(find.byKey(const Key('meal_desayuno')), findsOneWidget);

        await tester.tap(find.byKey(const Key('meal_desayuno_delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('meal_delete_confirm')));
        await tester.pumpAndSettle();

        expect(meals.deleted, ['desayuno']);
        expect(find.byKey(const Key('meal_desayuno')), findsNothing);
        expect(find.byKey(const Key('meal_comida')), findsOneWidget);
        expect(find.text('Registro eliminado'), findsOneWidget);
      },
    );

    testWidgets(
      'si el registro ya no existía recarga la lista y lo avisa (404 MEAL_NOT_FOUND)',
      (tester) async {
        await openHistory(tester);
        // Otro dispositivo ya lo eliminó.
        meals.days[today]!.removeWhere((meal) => meal.id == 'desayuno');

        await tester.tap(find.byKey(const Key('meal_desayuno_delete')));
        await tester.pumpAndSettle();
        // La recarga tarda: mientras, la lista (y la tarjeta) se reemplaza por la carga.
        final gate = meals.listGate = Completer<void>();
        await tester.tap(find.byKey(const Key('meal_delete_confirm')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('meal_desayuno')), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();

        expect(meals.listRequests, [today, today]);
        expect(find.byKey(const Key('meal_desayuno')), findsNothing);
        expect(find.byKey(const Key('meal_comida')), findsOneWidget);
        expect(
          find.text(MealHistoryViewModel.alreadyDeletedMessage),
          findsOneWidget,
        );
      },
    );
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
      // TEC-17: la barra inferior ocupa el pie de la pantalla; se lleva a la vista.
      await tester.ensureVisible(find.byKey(const Key('client_detail_meals')));
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

  group('progreso de un cliente (HU-23)', () {
    Future<void> openProgress(
      WidgetTester tester, {
      ApiException? progressError,
      bool withData = true,
    }) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      progress
        ..error = progressError
        ..withData = withData;
      await tester.tap(find.byKey(const Key('clients_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('client_${testClientSummary.id}')));
      await tester.pumpAndSettle();
      // TEC-17: la barra inferior ocupa el pie de la pantalla; se lleva a la vista.
      await tester.ensureVisible(
        find.byKey(const Key('client_detail_progress')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('client_detail_progress')));
      await tester.pumpAndSettle();
    }

    testWidgets('desde el detalle se abre el progreso semanal del cliente', (
      tester,
    ) async {
      await openProgress(tester);

      expect(find.byType(ClientProgressView), findsOneWidget);
      expect(
        find.text('Progreso de ${testClientSummary.name}'),
        findsOneWidget,
      );
      expect(progress.clientRequests, [testClientSummary.id]);
      expect(find.byKey(const Key('client_progress_weight')), findsOneWidget);
      expect(
        find.byKey(const Key('client_progress_weight_chart')),
        findsOneWidget,
      );
      // La lista se construye bajo demanda: se desplaza hasta las demás tarjetas.
      final list = find.descendant(
        of: find.byType(ClientProgressView),
        matching: find.byType(ListView),
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('client_progress_chart_calories')),
        list,
        const Offset(0, -200),
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('client_progress_compliance_chart')),
        list,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('es de solo lectura: sin botón para registrar peso', (
      tester,
    ) async {
      await openProgress(tester);

      expect(
        find.byKey(const Key('client_progress_register_weight')),
        findsNothing,
      );
      expect(find.byKey(const Key('progress_register_weight')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('cambia a mes', (tester) async {
      await openProgress(tester);

      await tester.tap(find.byKey(const Key('client_progress_range_month')));
      await tester.pumpAndSettle();

      final today = appDay(DateTime.now());
      expect(progress.requests.last, '${today.substring(0, 8)}01..$today');
      expect(progress.clientRequests.toSet(), {testClientSummary.id});
    });

    testWidgets('un periodo sin datos lo indica con textos para el coach', (
      tester,
    ) async {
      await openProgress(tester, withData: false);

      expect(
        find.text(
          'Tu cliente necesita al menos dos registros de peso en este periodo '
          'para ver su tendencia.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('un cliente desvinculado lo indica y regresa a la lista', (
      tester,
    ) async {
      await openProgress(
        tester,
        progressError: apiError(ApiErrorCode.clientNotLinked, status: 403),
      );

      expect(find.byKey(const Key('client_progress_unlinked')), findsOneWidget);
      await tester.tap(find.byKey(const Key('client_progress_back')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientsListView), findsOneWidget);
      expect(find.byType(ClientDetailView), findsNothing);
    });

    testWidgets('sin conexión muestra el error y permite reintentar', (
      tester,
    ) async {
      await openProgress(tester, progressError: networkError);
      expect(find.text(networkError.message), findsOneWidget);

      progress.error = null;
      await tester.tap(find.byKey(const Key('client_progress_retry')));
      await tester.pumpAndSettle();
      expect(find.text(networkError.message), findsNothing);
      expect(find.byKey(const Key('client_progress_weight')), findsOneWidget);
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

      // TEC-17: la barra inferior ocupa el pie de la pantalla; se lleva a la vista.
      await tester.ensureVisible(
        find.byKey(const Key('invite_code_regenerate')),
      );
      await tester.pumpAndSettle();
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

      // TEC-17: la barra inferior ocupa el pie de la pantalla; se lleva a la vista.
      await tester.ensureVisible(
        find.byKey(const Key('invite_code_regenerate')),
      );
      await tester.pumpAndSettle();
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

    testWidgets('abre la pantalla de vinculación con el coach desde el inicio', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      // Con el progreso del día (HU-10) el botón queda debajo de las tarjetas.
      await tester.scrollUntilVisible(
        find.byKey(const Key('link_coach_nav_button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('link_coach_nav_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('link_coach_nav_button')));
      await tester.pumpAndSettle();

      expect(find.text('Vincular con coach'), findsWidgets);
    });
  });

  group('rutinas del coach (HU-18)', () {
    Future<void> openRoutines(
      WidgetTester tester, {
      ApiException? routinesError,
    }) async {
      await pumpApp(
        tester,
        state: const Authenticated(testCoach),
        routinesError: routinesError,
      );
      await tester.tap(find.byKey(const Key('routines_home_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('el coach ve sus rutinas desde su pantalla principal', (
      tester,
    ) async {
      await openRoutines(tester);

      expect(find.byType(RoutinesListView), findsOneWidget);
      expect(find.text('Torso A'), findsOneWidget);
      expect(find.text('2 ejercicios · Pecho, Espalda'), findsOneWidget);
      expect(find.text('Pierna'), findsOneWidget);
    });

    testWidgets('también se abren desde la barra del panel', (tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      await tester.tap(find.byKey(const Key('routines_button')));
      await tester.pumpAndSettle();

      expect(find.byType(RoutinesListView), findsOneWidget);
    });

    testWidgets('sin rutinas lo indica', (tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      routines.routines = [];
      await tester.tap(find.byKey(const Key('routines_home_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routines_empty')), findsOneWidget);
      expect(find.byKey(const Key('routines_new')), findsOneWidget);
    });

    testWidgets('sin conexión muestra el error y permite reintentar', (
      tester,
    ) async {
      await openRoutines(tester, routinesError: networkError);
      expect(find.text(networkError.message), findsOneWidget);

      routines.listError = null;
      await tester.tap(find.byKey(const Key('routines_retry')));
      await tester.pumpAndSettle();
      expect(find.text('Torso A'), findsOneWidget);
    });

    testWidgets(
      'crea una rutina con ejercicios elegidos del catálogo filtrado',
      (tester) async {
        await openRoutines(tester);
        await tester.tap(find.byKey(const Key('routines_new')));
        await tester.pumpAndSettle();
        expect(find.byType(RoutineBuilderView), findsOneWidget);

        await tester.enterText(find.byKey(const Key('routine_name')), 'Empuje');
        await tester.tap(find.byKey(const Key('routine_add_exercises')));
        await tester.pumpAndSettle();
        expect(find.byType(ExercisePickerView), findsOneWidget);
        expect(find.text(testSquat.name), findsOneWidget);

        await tester.tap(find.byKey(const Key('exercise_filter_group_chest')));
        await tester.pumpAndSettle();
        expect(find.text(testSquat.name), findsNothing);
        expect(routines.exerciseRequests.last.muscleGroup?.apiValue, 'chest');

        await tester.tap(find.byKey(Key('exercise_${testPushUps.id}')));
        await tester.tap(find.byKey(Key('exercise_${testBenchPress.id}')));
        await tester.pump();
        expect(find.text('Agregar (2)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('exercise_picker_add')));
        await tester.pumpAndSettle();

        expect(find.byType(RoutineBuilderView), findsOneWidget);
        expect(find.text('1. ${testPushUps.name}'), findsOneWidget);
        expect(find.text('2. ${testBenchPress.name}'), findsOneWidget);

        await tester.tap(find.byKey(const Key('routine_submit')));
        await tester.pumpAndSettle();

        final draft = routines.created.single;
        expect(draft.name, 'Empuje');
        expect(draft.exercises.map((e) => (e.exerciseId, e.sets, e.reps)), [
          (testPushUps.id, 3, 10),
          (testBenchPress.id, 3, 10),
        ]);
        expect(find.byType(RoutinesListView), findsOneWidget);
        expect(find.text('Empuje'), findsOneWidget);
        expect(find.text('Rutina creada'), findsOneWidget);
      },
    );

    testWidgets('la validación local marca los campos y no guarda', (
      tester,
    ) async {
      await openRoutines(tester);
      await tester.tap(find.byKey(const Key('routines_new')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine_submit')));
      await tester.pumpAndSettle();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(
        find.text('La rutina debe tener al menos un ejercicio'),
        findsOneWidget,
      );
      expect(routines.created, isEmpty);
    });

    testWidgets('editar guarda los cambios y la lista se actualiza', (
      tester,
    ) async {
      await openRoutines(tester);
      await tester.tap(find.text('Torso A'));
      await tester.pumpAndSettle();
      expect(find.text('Editar rutina'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('routine_name')), 'Torso B');
      await tester.tap(find.byKey(const Key('routine_submit')));
      await tester.pumpAndSettle();

      expect(routines.updated.single.id, testRoutine.id);
      expect(find.byType(RoutinesListView), findsOneWidget);
      expect(find.text('Torso B'), findsOneWidget);
      expect(find.text('Torso A'), findsNothing);
    });

    testWidgets('eliminar pide confirmación y actualiza la lista', (
      tester,
    ) async {
      await openRoutines(tester);

      Future<void> askToDelete() async {
        await tester.tap(find.byKey(Key('routine_menu_${testRoutine.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('routine_menu_delete')));
        await tester.pumpAndSettle();
        expect(find.textContaining('¿Eliminar «Torso A»?'), findsOneWidget);
      }

      await askToDelete();
      await tester.tap(find.byKey(const Key('routine_delete_cancel')));
      await tester.pumpAndSettle();
      expect(routines.deleted, isEmpty);
      expect(find.text('Torso A'), findsOneWidget);

      await askToDelete();
      await tester.tap(find.byKey(const Key('routine_delete_confirm')));
      await tester.pumpAndSettle();
      expect(routines.deleted, [testRoutine.id]);
      expect(find.text('Torso A'), findsNothing);
      expect(find.text('Pierna'), findsOneWidget);
      expect(find.text('Rutina eliminada'), findsOneWidget);
    });

    testWidgets('salir con cambios sin guardar pide confirmación', (
      tester,
    ) async {
      await openRoutines(tester);
      await tester.tap(find.byKey(const Key('routines_new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('routine_name')), 'Torso');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('routine_discard_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineBuilderView), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine_discard_confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(RoutinesListView), findsOneWidget);
      expect(routines.created, isEmpty);
    });
  });

  group('asignar rutina a clientes (HU-19)', () {
    Future<void> openAssign(WidgetTester tester) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      await tester.tap(find.byKey(const Key('routines_home_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('routine_menu_${testRoutine.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine_menu_assign')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'desde el menú de la rutina se eligen clientes, se confirma y se regresa con el aviso',
      (tester) async {
        await pumpApp(tester, state: const Authenticated(testCoach));
        routines.assignments = {
          testRoutine.id: [
            testAssignment(clientId: testClientSummary.id, clientName: 'Ana'),
          ],
        };
        await tester.tap(find.byKey(const Key('routines_home_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('routine_menu_${testRoutine.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('routine_menu_assign')));
        await tester.pumpAndSettle();

        expect(find.byType(AssignRoutineView), findsOneWidget);
        expect(find.byKey(const Key('assign_routine_name')), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('José Pérez'), findsOneWidget);
        // Ana ya la tiene: marcada y bloqueada.
        expect(
          find.byKey(Key('assign_client_assigned_${testClientSummary.id}')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(Key('assign_client_${testClientSummary.id}')),
        );
        await tester.pump();
        expect(find.text('Asignar'), findsOneWidget);

        await tester.tap(
          find.byKey(Key('assign_client_${testClientWithoutData.id}')),
        );
        await tester.pump();
        expect(find.text('Asignar (1)'), findsOneWidget);

        await tester.tap(find.byKey(const Key('assign_routine_submit')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('«Torso A» se asignará a 1 cliente'),
          findsOneWidget,
        );
        expect(find.textContaining('• José Pérez'), findsOneWidget);

        await tester.tap(find.byKey(const Key('assign_routine_confirm')));
        await tester.pumpAndSettle();

        expect(routines.assignCalls.single.clientIds, [
          testClientWithoutData.id,
        ]);
        expect(find.byType(RoutinesListView), findsOneWidget);
        expect(find.text('«Torso A» se asignó a 1 cliente.'), findsOneWidget);
      },
    );

    testWidgets('cancelar el resumen no asigna', (tester) async {
      await openAssign(tester);
      await tester.tap(
        find.byKey(Key('assign_client_${testClientSummary.id}')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('assign_routine_submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_routine_cancel')));
      await tester.pumpAndSettle();

      expect(routines.assignCalls, isEmpty);
      expect(find.byType(AssignRoutineView), findsOneWidget);
    });

    testWidgets('sin clientes explica que primero debe vincularlos', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testCoach));
      clients.clients = [];
      await tester.tap(find.byKey(const Key('routines_home_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('routine_menu_${testRoutine.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine_menu_assign')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('assign_routine_no_clients')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('assign_routine_submit')), findsNothing);
      expect(
        find.byKey(const Key('assign_routine_invite_code')),
        findsOneWidget,
      );
    });

    testWidgets('salir sin asignar conserva la rutina (CU-04 5a)', (
      tester,
    ) async {
      await openAssign(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(RoutinesListView), findsOneWidget);
      expect(find.text('Torso A'), findsOneWidget);
      expect(routines.assignCalls, isEmpty);
      expect(routines.deleted, isEmpty);
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

    testWidgets('muestra el progreso del día con consumido, meta y restante', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));

      expect(find.text('1050.5 / 2200 kcal'), findsOneWidget);
      expect(find.text('Te faltan 1149.5 kcal'), findsOneWidget);
      expect(find.text('70 / 160 g'), findsOneWidget);
      expect(find.text('Te faltan 90 g'), findsOneWidget);
      expect(find.text('35.5 / 70 g'), findsOneWidget);
      expect(find.byKey(const Key('home_summary_fat_bar')), findsOneWidget);
    });

    testWidgets('con exceso la barra se llena y dice cuánto se pasó', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        summaryRepository: FakeSummaryRepository(
          daily: testDaySummary(
            consumed: const MacroValues(
              caloriesKcal: 2350,
              proteinG: 100,
              fatG: 40,
            ),
          ),
        ),
      );

      expect(find.text('Te pasaste por 150 kcal'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_summary_calories_bar')),
      );
      expect(bar.value, 1);
    });

    testWidgets('un día sin registros muestra consumo en 0', (tester) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        summaryRepository: FakeSummaryRepository(
          daily: testDaySummary(
            consumed: const MacroValues(caloriesKcal: 0, proteinG: 0, fatG: 0),
          ),
        ),
      );

      expect(find.text('0 / 2200 kcal'), findsOneWidget);
      expect(find.text('Te faltan 2200 kcal'), findsOneWidget);
    });

    testWidgets('sin meta el resumen muestra un mensaje y no un error', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        summaryRepository: FakeSummaryRepository.withoutGoal(),
      );

      expect(find.byKey(const Key('home_summary_empty')), findsOneWidget);
      expect(find.byKey(const Key('home_summary_retry')), findsNothing);
    });

    testWidgets('sin conexión el resumen muestra el error y reintenta', (
      tester,
    ) async {
      await pumpApp(
        tester,
        state: const Authenticated(testUser),
        summaryRepository: FakeSummaryRepository()..error = networkError,
      );

      expect(find.text(networkError.message), findsOneWidget);
      summary.error = null;
      await tester.tap(find.byKey(const Key('home_summary_retry')));
      await tester.pumpAndSettle();

      expect(find.text(networkError.message), findsNothing);
      expect(find.text('Te faltan 1149.5 kcal'), findsOneWidget);
      expect(summary.dailyDates, hasLength(2));
    });

    testWidgets('al regresar de registrar una comida se vuelve a consultar', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));
      expect(summary.dailyDates, hasLength(1));

      await tester.tap(find.byKey(const Key('register_meal_button')));
      await tester.pumpAndSettle();
      summary.daily = testDaySummary(
        consumed: const MacroValues(caloriesKcal: 1500, proteinG: 90, fatG: 50),
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(summary.dailyDates, hasLength(2));
      expect(find.text('1500 / 2200 kcal'), findsOneWidget);
    });

    testWidgets('al deslizar para actualizar se consulta de nuevo', (
      tester,
    ) async {
      await pumpApp(tester, state: const Authenticated(testUser));

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(summary.dailyDates, hasLength(2));
      expect(goals.currentCalls, 2);
    });

    group('resumen semanal (HU-11)', () {
      Future<void> openWeekly(
        WidgetTester tester, {
        FakeSummaryRepository? repository,
      }) async {
        // Alto suficiente para que la lista construya los 7 días.
        tester.view.physicalSize = const Size(800, 3200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          state: const Authenticated(testUser),
          summaryRepository: repository,
        );
        await tester.tap(find.byKey(const Key('weekly_summary_button')));
        await tester.pumpAndSettle();
      }

      testWidgets('el botón del inicio abre el resumen semanal', (
        tester,
      ) async {
        await openWeekly(tester);

        expect(find.byType(WeeklySummaryView), findsOneWidget);
        expect(summary.weeklyStarts, hasLength(1));
        // La semana inicial termina hoy: empieza 6 días antes.
        expect(
          summary.weeklyStarts.single,
          shiftDay(appDay(DateTime.now()), -6),
        );
      });

      testWidgets('muestra las calorías de los 7 días contra la meta', (
        tester,
      ) async {
        await openWeekly(tester);

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'weekly_bar_2',
                ),
          ),
          findsNWidgets(7),
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'weekly_goal_2',
                ),
          ),
          findsNWidgets(7),
        );
        expect(find.text('1900 / 2000 kcal'), findsNWidgets(5));
        expect(find.text('2400 / 2000 kcal'), findsOneWidget);
      });

      testWidgets('los días sin registros aparecen en 0', (tester) async {
        await openWeekly(
          tester,
          repository: FakeSummaryRepository(weekly: testEmptyWeekSummary()),
        );

        expect(find.text('0 / 2000 kcal'), findsNWidgets(7));
        expect(find.text('Días con la meta cumplida: 0 de 7'), findsOneWidget);
      });

      testWidgets('muestra el promedio y los días con la meta cumplida', (
        tester,
      ) async {
        await openWeekly(tester);

        expect(find.text('1700 kcal'), findsOneWidget);
        expect(find.text('124.3 g'), findsOneWidget);
        expect(find.text('50.7 g'), findsOneWidget);
        expect(find.text('Días con la meta cumplida: 5 de 7'), findsOneWidget);
      });

      testWidgets('cada día indica si cumplió la meta sin depender del color', (
        tester,
      ) async {
        await openWeekly(tester);

        expect(find.text('Meta cumplida'), findsNWidgets(5));
        expect(find.text('Meta no cumplida'), findsNWidgets(2));
        expect(find.byIcon(LucideIcons.circleCheck), findsNWidgets(10));
        expect(find.byIcon(LucideIcons.circleX), findsNWidgets(4));
      });

      testWidgets('cambia a la semana anterior y regresa a la siguiente', (
        tester,
      ) async {
        await openWeekly(tester);
        final next = find.byKey(const Key('weekly_next'));
        // La semana inicial termina hoy: no hay una siguiente.
        expect(tester.widget<IconButton>(next).onPressed, isNull);

        await tester.tap(find.byKey(const Key('weekly_previous')));
        await tester.pumpAndSettle();
        final today = appDay(DateTime.now());
        expect(summary.weeklyStarts.last, shiftDay(today, -13));
        expect(tester.widget<IconButton>(next).onPressed, isNotNull);

        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(summary.weeklyStarts.last, shiftDay(today, -6));
        expect(tester.widget<IconButton>(next).onPressed, isNull);
      });

      testWidgets('sin meta muestra un mensaje y no un error', (tester) async {
        await openWeekly(
          tester,
          repository: FakeSummaryRepository.withoutGoal(),
        );

        expect(find.byKey(const Key('weekly_empty')), findsOneWidget);
        expect(find.byKey(const Key('weekly_retry')), findsNothing);
      });

      testWidgets('sin conexión muestra el error en español y reintenta', (
        tester,
      ) async {
        await openWeekly(
          tester,
          repository: FakeSummaryRepository()..error = networkError,
        );

        expect(find.text(networkError.message), findsOneWidget);
        expect(find.byType(WeeklySummaryView), findsOneWidget);
        summary.error = null;
        await tester.tap(find.byKey(const Key('weekly_retry')));
        await tester.pumpAndSettle();

        expect(find.text(networkError.message), findsNothing);
        expect(find.text('Días con la meta cumplida: 5 de 7'), findsOneWidget);
      });
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
