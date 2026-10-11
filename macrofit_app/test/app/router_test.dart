import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/router.dart';
import 'package:macrofit_app/app/routes.dart';
import 'package:macrofit_app/features/auth/domain/entities/auth_state.dart';

import '../helpers/fakes.dart';

void main() {
  group('sin sesión', () {
    const state = Unauthenticated();

    test('permite login, registro y aviso de privacidad', () {
      for (final route in AppRoutes.public) {
        expect(resolveRedirect(state, route), isNull, reason: route);
      }
    });

    test(
      'las pantallas protegidas mandan a login (atrás tras cerrar sesión)',
      () {
        for (final route in [
          AppRoutes.userHome,
          AppRoutes.coachHome,
          AppRoutes.profileSetup,
          AppRoutes.profileEdit,
          AppRoutes.splash,
        ]) {
          expect(resolveRedirect(state, route), AppRoutes.login, reason: route);
        }
      },
    );
  });

  group('con sesión', () {
    test('un usuario va a la pantalla principal de usuario', () {
      const state = Authenticated(testUser);
      expect(resolveRedirect(state, AppRoutes.login), AppRoutes.userHome);
      expect(resolveRedirect(state, AppRoutes.splash), AppRoutes.userHome);
      expect(resolveRedirect(state, AppRoutes.userHome), isNull);
    });

    test('un coach va a la pantalla principal de coach', () {
      const state = Authenticated(testCoach);
      expect(resolveRedirect(state, AppRoutes.register), AppRoutes.coachHome);
      expect(resolveRedirect(state, AppRoutes.coachHome), isNull);
    });

    test('ningún rol accede a la pantalla del otro', () {
      expect(
        resolveRedirect(const Authenticated(testUser), AppRoutes.coachHome),
        AppRoutes.userHome,
      );
      expect(
        resolveRedirect(const Authenticated(testCoach), AppRoutes.userHome),
        AppRoutes.coachHome,
      );
    });

    test('el aviso de privacidad sigue disponible', () {
      expect(
        resolveRedirect(const Authenticated(testUser), AppRoutes.privacyNotice),
        isNull,
      );
      expect(
        resolveRedirect(
          const Authenticated(testNewUser),
          AppRoutes.privacyNotice,
        ),
        isNull,
      );
    });
  });

  group('metas por coach (HU-05)', () {
    test('un coach abre sus pantallas de clientes y metas', () {
      const state = Authenticated(testCoach);
      for (final route in [
        AppRoutes.coachClients,
        AppRoutes.coachClientGoals('abc'),
      ]) {
        expect(resolveRedirect(state, route), isNull, reason: route);
      }
    });

    test('un usuario no accede a las pantallas del coach', () {
      const state = Authenticated(testUser);
      for (final route in [
        AppRoutes.coachClients,
        AppRoutes.coachClientGoals('abc'),
      ]) {
        expect(
          resolveRedirect(state, route),
          AppRoutes.userHome,
          reason: route,
        );
      }
    });

    test('sin sesión las pantallas del coach mandan a login', () {
      expect(
        resolveRedirect(const Unauthenticated(), AppRoutes.coachClients),
        AppRoutes.login,
      );
    });

    test('una ruta parecida a la del coach no cuenta como suya', () {
      expect(AppRoutes.isCoachRoute('/coachmate'), isFalse);
    });
  });

  group('perfil inicial (HU-03)', () {
    test('un usuario sin perfil solo puede abrir el formulario de perfil', () {
      const state = Authenticated(testNewUser);
      for (final route in [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.userHome,
        AppRoutes.profileEdit,
        AppRoutes.coachHome,
      ]) {
        expect(
          resolveRedirect(state, route),
          AppRoutes.profileSetup,
          reason: route,
        );
      }
      expect(resolveRedirect(state, AppRoutes.profileSetup), isNull);
    });

    test('con perfil ya no ve el formulario y puede abrir Mi perfil', () {
      const state = Authenticated(testUser);
      expect(
        resolveRedirect(state, AppRoutes.profileSetup),
        AppRoutes.userHome,
      );
      expect(resolveRedirect(state, AppRoutes.profileEdit), isNull);
    });

    test('un coach nunca ve el formulario ni la edición del perfil', () {
      const state = Authenticated(testCoach);
      expect(testCoach.profileCompleted, isFalse);
      expect(
        resolveRedirect(state, AppRoutes.profileSetup),
        AppRoutes.coachHome,
      );
      expect(
        resolveRedirect(state, AppRoutes.profileEdit),
        AppRoutes.coachHome,
      );
      expect(resolveRedirect(state, AppRoutes.login), AppRoutes.coachHome);
    });
  });

  test('mientras se lee la sesión se muestra la carga inicial', () {
    expect(
      resolveRedirect(const AuthUnknown(), AppRoutes.login),
      AppRoutes.splash,
    );
    expect(resolveRedirect(const AuthUnknown(), AppRoutes.splash), isNull);
  });
}
