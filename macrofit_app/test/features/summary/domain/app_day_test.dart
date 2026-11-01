import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/summary/domain/usecases/app_day.dart';

void main() {
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
