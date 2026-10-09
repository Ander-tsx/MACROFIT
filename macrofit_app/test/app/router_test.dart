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
