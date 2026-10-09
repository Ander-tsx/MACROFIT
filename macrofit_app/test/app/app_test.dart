import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/app.dart';
import 'package:macrofit_app/app/dependencies.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';
import 'package:macrofit_app/features/auth/presentation/login/login_view.dart';
import 'package:macrofit_app/features/auth/presentation/register/register_view.dart';
import 'package:macrofit_app/features/auth/presentation/splash/splash_view.dart';
import 'package:macrofit_app/features/home/presentation/coach_home_view.dart';
import 'package:macrofit_app/features/home/presentation/user_home_view.dart';
import 'package:macrofit_app/features/legal/presentation/privacy_notice/privacy_notice_view.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeLegalRepository legal;

  Future<void> pumpApp(
    WidgetTester tester, {
    AuthState state = const Unauthenticated(),
    bool settle = true,
  }) async {
    auth = FakeAuthRepository(initialState: state);
    legal = FakeLegalRepository();
    await tester.pumpWidget(
      MacroFitApp(
        dependencies: AppDependencies(
          authRepository: auth,
          legalRepository: legal,
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
}
