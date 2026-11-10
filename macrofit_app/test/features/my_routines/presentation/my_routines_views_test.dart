import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:macrofit_app/app/routes.dart';
import 'package:macrofit_app/app/theme.dart';
import 'package:macrofit_app/features/my_routines/domain/entities/user_routine.dart';
import 'package:macrofit_app/features/my_routines/presentation/routine_detail/routine_detail_view.dart';
import 'package:macrofit_app/features/my_routines/presentation/routine_detail/routine_detail_view_model.dart';
import 'package:macrofit_app/features/my_routines/presentation/routines_list/my_routines_list_view.dart';
import 'package:macrofit_app/features/my_routines/presentation/routines_list/my_routines_list_view_model.dart';
import 'package:macrofit_app/features/summary/domain/usecases/app_day.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fakes.dart';

/// Lista y detalle con las mismas rutas que la app (`/user/routines`).
Future<void> pumpRoutines(
  WidgetTester tester,
  FakeMyRoutinesRepository repository,
) async {
  final router = GoRouter(
    initialLocation: AppRoutes.myRoutines,
    routes: [
      GoRoute(
        path: AppRoutes.userHome,
        builder: (_, _) => const SizedBox(),
        routes: [
          GoRoute(
            path: AppRoutes.myRoutinesChild,
            builder: (_, _) => ChangeNotifierProvider(
              create: (_) => MyRoutinesListViewModel(repository)..load(),
              child: const MyRoutinesListView(),
            ),
          ),
          GoRoute(
            path: AppRoutes.myRoutineDetailChild,
            builder: (_, state) => ChangeNotifierProvider(
              create: (_) => RoutineDetailViewModel(
                repository: repository,
                routineId: state.pathParameters['routineId']!,
                summary: state.extra is UserRoutineSummary
                    ? state.extra! as UserRoutineSummary
                    : null,
              )..load(),
              child: const RoutineDetailView(),
            ),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la lista etiqueta cada rutina con su origen y su coach', (
    tester,
  ) async {
    await pumpRoutines(
      tester,
      FakeMyRoutinesRepository(
        routines: [testRecommendedRoutine(), testAssignedRoutine()],
      ),
    );

    expect(find.text('Rutina recomendada · Mantener · 3 días'), findsOneWidget);
    expect(find.text('Recomendada'), findsOneWidget);
    expect(find.text('3 sesiones'), findsOneWidget);
    expect(find.text('Torso A'), findsOneWidget);
    expect(find.text('Asignada por Carlos'), findsOneWidget);
    expect(find.text('1 sesión'), findsOneWidget);
  });

  testWidgets(
    'el detalle muestra sesiones, ejercicios, series, reps y descanso',
    (tester) async {
      final repository = FakeMyRoutinesRepository(
        routines: [testAssignedRoutine()],
      );
      await pumpRoutines(tester, repository);

      await tester.tap(find.byKey(const Key('my_routine_asg1')));
      await tester.pumpAndSettle();

      expect(repository.detailRequests, ['asg1']);
      expect(find.byKey(const Key('routine_session_1')), findsOneWidget);
      expect(find.text('Press de banca'), findsOneWidget);
      expect(
        find.text('Pecho · 4 series × 10 reps · 90 s de descanso'),
        findsOneWidget,
      );
      expect(find.text('Asignada por Carlos'), findsOneWidget);
    },
  );

  testWidgets('una rutina retirada avisa y regresa a la lista recargada', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository(
      routines: [testAssignedRoutine()],
    );
    await pumpRoutines(tester, repository);

    // El coach la retira mientras la lista está abierta.
    repository.routines = [];
    await tester.tap(find.byKey(const Key('my_routine_asg1')));
    await tester.pumpAndSettle();

    expect(find.text(RoutineDetailView.unavailableMessage), findsWidgets);
    expect(find.byType(MyRoutinesListView), findsOneWidget);
    expect(find.byType(RoutineDetailView), findsNothing);
    expect(repository.listCalls, 2, reason: 'al volver se recarga');
    expect(find.byKey(const Key('my_routines_empty')), findsOneWidget);
  });

  testWidgets('sin rutinas ofrece la recomendada y abre su detalle', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository();
    await pumpRoutines(tester, repository);

    expect(find.byKey(const Key('my_routines_empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('my_routines_recommended')));
    await tester.pumpAndSettle();

    expect(repository.recommendedCalls, 1);
    expect(find.byType(RoutineDetailView), findsOneWidget);
    expect(find.text('Día 3 · Cuerpo completo'), findsOneWidget);
  });

  testWidgets('sin conexión muestra el error en español y permite reintentar', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository(
      routines: [testAssignedRoutine()],
    )..listError = networkError;
    await pumpRoutines(tester, repository);

    expect(find.text('Sin conexión'), findsOneWidget);
    repository.listError = null;
    await tester.tap(find.byKey(const Key('my_routines_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Torso A'), findsOneWidget);
  });

  group('marcar sesión como completada (HU-17)', () {
    Future<FakeMyRoutinesRepository> openDetail(WidgetTester tester) async {
      final repository = FakeMyRoutinesRepository(
        routines: [testAssignedRoutine()],
      )..today = appDay(DateTime.now());
      await pumpRoutines(tester, repository);
      await tester.tap(find.byKey(const Key('my_routine_asg1')));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('confirmar marca la sesión con su fecha y quita el botón', (
      tester,
    ) async {
      final repository = await openDetail(tester);

      await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
      await tester.tap(find.byKey(const Key('complete_session_1')));
      await tester.pumpAndSettle();
      expect(find.text('¿Terminaste «Torso A» hoy?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('complete_session_confirm')));
      await tester.pumpAndSettle();

      expect(repository.completeRequests, [('asg1', 1)]);
      expect(find.byKey(const Key('session_completed_1')), findsOneWidget);
      expect(find.textContaining('Completada hoy'), findsOneWidget);
      expect(find.byKey(const Key('complete_session_1')), findsNothing);
      expect(find.text('Sesión registrada. ¡Bien hecho!'), findsOneWidget);
    });

    testWidgets('cancelar no registra la sesión', (tester) async {
      final repository = await openDetail(tester);

      await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
      await tester.tap(find.byKey(const Key('complete_session_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete_session_cancel')));
      await tester.pumpAndSettle();

      expect(repository.completeRequests, isEmpty);
      expect(find.byKey(const Key('complete_session_1')), findsOneWidget);
    });

    testWidgets(
      'sin conexión muestra el error en la sesión y permite reintentar',
      (tester) async {
        final repository = await openDetail(tester);
        repository.completeError = networkError;

        await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
        await tester.tap(find.byKey(const Key('complete_session_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('complete_session_confirm')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('complete_session_error_1')),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);

        repository.completeError = null;
        await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
        await tester.tap(find.byKey(const Key('complete_session_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('complete_session_confirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('session_completed_1')), findsOneWidget);
      },
    );

    testWidgets('ya registrada hoy en otro dispositivo: lo indica y la marca', (
      tester,
    ) async {
      final repository = await openDetail(tester);
      repository.completedElsewhere = true;

      await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
      await tester.tap(find.byKey(const Key('complete_session_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete_session_confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text(RoutineDetailView.alreadyCompletedMessage),
        findsOneWidget,
      );
      expect(find.byKey(const Key('session_completed_1')), findsOneWidget);
    });

    testWidgets(
      'si la rutina se retiró al marcar, avisa y regresa a la lista',
      (tester) async {
        final repository = await openDetail(tester);
        repository.routines = [];

        await tester.ensureVisible(find.byKey(const Key('complete_session_1')));
        await tester.tap(find.byKey(const Key('complete_session_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('complete_session_confirm')));
        await tester.pumpAndSettle();

        expect(find.text(RoutineDetailView.unavailableMessage), findsWidgets);
        expect(find.byType(RoutineDetailView), findsNothing);
        expect(find.byType(MyRoutinesListView), findsOneWidget);
      },
    );
  });
}
