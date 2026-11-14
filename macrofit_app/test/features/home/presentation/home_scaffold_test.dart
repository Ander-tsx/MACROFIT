import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/home/presentation/widgets/home_scaffold.dart';

void main() {
  group('firstName (saludo del inicio)', () {
    test('usa solo el primer nombre para que el saludo no se corte', () {
      expect(firstName('Andres Garcia Lopez'), 'Andres');
      expect(firstName('  Ana   María '), 'Ana');
    });

    test('un nombre de una palabra queda igual y vacío da vacío', () {
      expect(firstName('Carlos'), 'Carlos');
      expect(firstName(''), '');
    });
  });
}
