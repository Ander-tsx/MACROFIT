import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/auth/domain/entities/role.dart';
import 'package:macrofit_app/features/auth/domain/validators/auth_validators.dart';

void main() {
  group('correo', () {
    test('acepta correos válidos', () {
      for (final email in [
        'ana@macrofit.com',
        'a.b+c@sub.dominio.mx',
        'x@y.io',
      ]) {
        expect(AuthValidators.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rechaza correos inválidos (mismos casos que el backend)', () {
      for (final email in [
        '',
        'sin-arroba.com',
        '@macrofit.com',
        'ana@',
        'ana@macrofit',
        'ana@@macrofit.com',
        'ana @macrofit.com',
        'ana@macrofit..com',
        'ana@.macrofit.com',
      ]) {
        expect(AuthValidators.isValidEmail(email), isFalse, reason: email);
      }
    });

    test('vacío pide el correo', () {
      expect(AuthValidators.email('  '), 'El correo es obligatorio');
    });
  });

  group('contraseña', () {
    test('menos de 8 caracteres es inválida y 8 es válida', () {
      expect(AuthValidators.newPassword('1234567'), contains('al menos 8'));
      expect(AuthValidators.newPassword('12345678'), isNull);
    });

    test('las contraseñas deben coincidir', () {
      expect(
        AuthValidators.passwordConfirmation('Segura123', 'Segura124'),
        'Las contraseñas no coinciden',
      );
      expect(
        AuthValidators.passwordConfirmation('Segura123', ''),
        'Confirma tu contraseña',
      );
      expect(
        AuthValidators.passwordConfirmation('Segura123', 'Segura123'),
        isNull,
      );
    });

    test('en el login solo se exige que no esté vacía', () {
      expect(AuthValidators.loginPassword(''), isNotNull);
      expect(AuthValidators.loginPassword('1'), isNull);
    });
  });

  test('nombre vacío o en blanco es inválido', () {
    expect(AuthValidators.name(''), 'El nombre es obligatorio');
    expect(AuthValidators.name('   '), 'El nombre es obligatorio');
    expect(AuthValidators.name('Ana'), isNull);
  });

  test('rol y aviso de privacidad son obligatorios', () {
    expect(AuthValidators.role(null), 'Debes elegir un rol');
    expect(AuthValidators.role(Role.coach), isNull);
    expect(
      AuthValidators.privacyAccepted(false),
      'Debes aceptar el aviso de privacidad',
    );
    expect(AuthValidators.privacyAccepted(true), isNull);
  });
}
