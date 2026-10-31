import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/summary/domain/usecases/app_day.dart';

void main() {
  _shiftTests();

  test('el día de la app es el de México (UTC-6), no el UTC', () {
    expect(appDay(DateTime.utc(2026, 10, 17, 2, 30)), '2026-10-16');
    expect(appDay(DateTime.utc(2026, 10, 17, 6, 0)), '2026-10-17');
  });

  test('cruza el cambio de mes y de año', () {
    expect(appDay(DateTime.utc(2026, 11, 1, 5, 59)), '2026-10-31');
    expect(appDay(DateTime.utc(2027, 1, 1, 3)), '2026-12-31');
  });

  test('completa mes y día con cero', () {
    expect(appDay(DateTime.utc(2026, 3, 5, 12)), '2026-03-05');
  });

  test('da el mismo día sin importar la zona del DateTime recibido', () {
    final utc = DateTime.utc(2026, 10, 17, 2, 30);
    expect(appDay(utc.toLocal()), appDay(utc));
  });
}

void _shiftTests() {
  group('shiftDay', () {
    test('suma y resta días cruzando mes y año', () {
      expect(shiftDay('2026-10-31', 1), '2026-11-01');
      expect(shiftDay('2026-01-02', -3), '2025-12-30');
      expect(shiftDay('2026-10-22', -6), '2026-10-16');
    });

    test('respeta los años bisiestos', () {
      expect(shiftDay('2028-02-28', 1), '2028-02-29');
      expect(shiftDay('2026-02-28', 1), '2026-03-01');
    });
  });

  test('weekdayOf, dayOfMonth y monthOf leen el día YYYY-MM-DD', () {
    // 16 de octubre de 2026 es viernes.
    expect(weekdayOf('2026-10-16'), DateTime.friday);
    expect(dayOfMonth('2026-10-16'), 16);
    expect(monthOf('2026-10-16'), 10);
  });
}
