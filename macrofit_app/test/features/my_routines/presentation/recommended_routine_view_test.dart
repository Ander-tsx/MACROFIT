import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:macrofit_app/app/routes.dart';
import 'package:macrofit_app/app/theme.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/core/presentation/widgets/primary_button.dart';
import 'package:macrofit_app/features/my_routines/presentation/recommended/recommended_routine_view.dart';
import 'package:macrofit_app/features/my_routines/presentation/recommended/recommended_routine_view_model.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fakes.dart';

/// Pantalla con las mismas rutas que la app; el detalle y el perfil son marcadores.
Future<void> pumpRecommended(
  WidgetTester tester,
  FakeMyRoutinesRepository repository,
) async {
  final router = GoRouter(
    initialLocation: AppRoutes.recommendedRoutine,
    routes: [
      GoRoute(
        path: AppRoutes.userHome,
        builder: (_, _) => const SizedBox(),
        routes: [
          GoRoute(
            path: AppRoutes.recommendedRoutineChild,
            builder: (_, _) => ChangeNotifierProvider(
              create: (_) => RecommendedRoutineViewModel(repository)..load(),
              child: const RecommendedRoutineView(),
            ),
          ),
          GoRoute(
            path: AppRoutes.myRoutineDetailChild,
            builder: (_, state) =>
                Text('detalle ${state.pathParameters['routineId']}'),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const Text('perfil'),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  await tester.pumpAndSettle();
}

const _generate = Key('recommended_generate');
const _regenerate = Key('recommended_regenerate');
const _confirm = Key('recommended_regenerate_confirm');
const _cancel = Key('recommended_regenerate_cancel');

void main() {
  setUp(() {
    // La lista de sesiones es larga: pantalla alta para no depender del scroll.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1200,
      6000,
    );
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
  });

  testWidgets('sin rutina ofrece generarla y abrir no la genera', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository();
    await pumpRecommended(tester, repository);

    expect(find.byKey(_generate), findsOneWidget);
    expect(repository.recommendedCalls, 0);
  });

  testWidgets('mientras se genera hay carga y el botón no envía dos veces', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeMyRoutinesRepository()..recommendedGate = gate;
    await pumpRecommended(tester, repository);

    await tester.tap(find.byKey(_generate));
    await tester.pump();

    expect(find.text('Generando tu rutina…'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byKey(_generate)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(_generate), warnIfMissed: false);
    await tester.pump();
    expect(repository.recommendedCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recommended_summary')), findsOneWidget);
  });

  testWidgets('muestra nombre, objetivo, nivel, días y cada sesión', (
    tester,
  ) async {
    await pumpRecommended(tester, FakeMyRoutinesRepository());

    await tester.tap(find.byKey(_generate));
    await tester.pumpAndSettle();

    expect(find.text('Rutina recomendada · Mantener · 3 días'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text('Mantener'), findsOneWidget);
    expect(find.text('Nivel'), findsOneWidget);
    expect(find.text('Principiante'), findsOneWidget);
    expect(find.text('Días'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    for (var n = 1; n <= 3; n++) {
      expect(find.text('Día $n · Cuerpo completo'), findsOneWidget);
    }
    expect(find.text('Sentadilla'), findsNWidgets(3));
    expect(
      find.text('Piernas · 2 series × 12 reps · 60 s de descanso'),
      findsNWidgets(3),
    );
  });

  testWidgets('generarla de nuevo pide confirmación y muestra la nueva', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository();
    await pumpRecommended(tester, repository);
    await tester.tap(find.byKey(_generate));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_regenerate));
    await tester.pumpAndSettle();
    expect(find.textContaining('se reemplazará'), findsOneWidget);
    await tester.tap(find.byKey(_cancel));
    await tester.pumpAndSettle();
    expect(repository.recommendedCalls, 1, reason: 'cancelar no genera');

    await tester.tap(find.byKey(_regenerate));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();

    expect(repository.recommendedCalls, 2);
    expect(find.byKey(const Key('recommended_summary')), findsOneWidget);
    expect(find.text('Tu rutina recomendada está lista.'), findsOneWidget);
  });

  testWidgets('con una vigente la muestra, la abre y regenerar confirma', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository(
      routines: [testRecommendedRoutine()],
    );
    await pumpRecommended(tester, repository);

    expect(find.byKey(_generate), findsNothing);
    expect(find.text('3 sesiones'), findsOneWidget);

    await tester.tap(find.byKey(_regenerate));
    await tester.pumpAndSettle();
    expect(find.byKey(_confirm), findsOneWidget);
    await tester.tap(find.byKey(_cancel));
    await tester.pumpAndSettle();
    expect(repository.recommendedCalls, 0);

    await tester.tap(find.byKey(const Key('recommended_existing')));
    await tester.pumpAndSettle();
    expect(find.text('detalle rec1'), findsOneWidget);
  });

  testWidgets('sin perfil muestra el mensaje y lleva a completarlo', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository()
      ..recommendedError = apiError(ApiErrorCode.profileNotFound, status: 404);
    await pumpRecommended(tester, repository);

    await tester.tap(find.byKey(_generate));
    await tester.pumpAndSettle();

    expect(
      find.text('Completa tu perfil para recibir una rutina recomendada.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('recommended_complete_profile')));
    await tester.pumpAndSettle();
    expect(find.text('perfil'), findsOneWidget);
  });

  for (final (name, code, status) in [
    ('el catálogo incompleto', ApiErrorCode.exerciseCatalogIncomplete, 503),
    ('la falta de conexión', ApiErrorCode.network, 0),
  ]) {
    testWidgets('$name muestra el mensaje y permite reintentar', (
      tester,
    ) async {
      final repository = FakeMyRoutinesRepository()
        ..recommendedError = apiError(
          code,
          status: status,
          message: 'Intenta más tarde',
        );
      await pumpRecommended(tester, repository);

      await tester.tap(find.byKey(_generate));
      await tester.pumpAndSettle();

      expect(find.text('Intenta más tarde'), findsOneWidget);

      repository.recommendedError = null;
      await tester.tap(find.byKey(_generate));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recommended_summary')), findsOneWidget);
    });
  }

  testWidgets('si no se pudo revisar la rutina permite reintentar', (
    tester,
  ) async {
    final repository = FakeMyRoutinesRepository()
      ..listError = apiError(
        ApiErrorCode.network,
        status: 0,
        message: 'Sin conexión',
      );
    await pumpRecommended(tester, repository);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.byKey(_generate), findsNothing);

    repository.listError = null;
    await tester.tap(find.byKey(const Key('recommended_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(_generate), findsOneWidget);
  });
}
