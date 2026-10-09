import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';
import 'package:macrofit_app/features/profile/domain/validators/profile_validators.dart';

void main() {
  final today = DateTime(2026, 10, 8);

  group('selecciones obligatorias', () {
    test('sin objetivo, nivel o sexo se rechazan', () {
      expect(ProfileValidators.objective(null), isNotNull);
      expect(ProfileValidators.level(null), isNotNull);
      expect(ProfileValidators.gender(null), isNotNull);
    });

    test('con una opción elegida se aceptan', () {
      expect(ProfileValidators.objective(Objective.maintain), isNull);
      expect(ProfileValidators.level(ExperienceLevel.advanced), isNull);
      expect(ProfileValidators.gender(Gender.male), isNull);
    });
  });

  test('días de entrenamiento de 1 a 7', () {
    expect(ProfileValidators.trainingDays(null), isNotNull);
    expect(ProfileValidators.trainingDays(0), isNotNull);
    expect(ProfileValidators.trainingDays(8), isNotNull);
    for (var days = 1; days <= 7; days++) {
      expect(ProfileValidators.trainingDays(days), isNull, reason: '$days');
    }
  });

  group('peso (30 a 300 kg)', () {
    test('vacío o no numérico se rechaza', () {
      expect(ProfileValidators.weight(''), 'El peso es obligatorio');
      expect(ProfileValidators.weight('  '), 'El peso es obligatorio');
      expect(ProfileValidators.weight('abc'), 'Escribe un número válido');
    });

    test('fuera de rango se rechaza y los límites se aceptan', () {
      expect(ProfileValidators.weight('29.9'), isNotNull);
      expect(ProfileValidators.weight('300.1'), isNotNull);
      expect(ProfileValidators.weight('30'), isNull);
      expect(ProfileValidators.weight('300'), isNull);
    });

    test('acepta coma decimal', () {
      expect(ProfileValidators.weight('72,5'), isNull);
      expect(ProfileValidators.parseNumber('72,5'), 72.5);
    });
  });

  test('estatura de 100 a 250 cm', () {
    expect(ProfileValidators.height(''), 'La estatura es obligatoria');
    expect(ProfileValidators.height('99.9'), isNotNull);
    expect(ProfileValidators.height('250.5'), isNotNull);
    expect(ProfileValidators.height('100'), isNull);
    expect(ProfileValidators.height('250'), isNull);
  });

  group('fecha de nacimiento (18 a 100 años)', () {
    String? validate(DateTime? date) =>
        ProfileValidators.birthDate(date, today: today);

    test('obligatoria y no futura', () {
      expect(validate(null), isNotNull);
      expect(validate(DateTime(2027, 1, 1)), isNotNull);
    });

    test('18 años cumplidos hoy es válido; un día antes no', () {
      expect(validate(DateTime(2008, 10, 8)), isNull);
      expect(validate(DateTime(2008, 10, 9)), isNotNull);
    });

    test('100 años es válido; 101 no', () {
      expect(validate(DateTime(1925, 10, 9)), isNull);
      expect(validate(DateTime(1925, 10, 8)), isNotNull);
    });

    test('calcula los años cumplidos', () {
      expect(ProfileValidators.ageOn(DateTime(1996, 5, 20), today), 30);
      expect(ProfileValidators.ageOn(DateTime(1996, 12, 20), today), 29);
      expect(ProfileValidators.ageOn(DateTime(2026, 10, 9), today), -1);
    });
  });
}
