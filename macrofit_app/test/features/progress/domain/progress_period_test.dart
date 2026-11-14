import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/progress/domain/entities/progress_period.dart';

void main() {
  const today = '2026-11-05';

  group('semana', () {
    test('la actual son los 7 días que terminan hoy', () {
      final week = ProgressPeriod.current(ProgressRange.week, today);
      expect(week.from, '2026-10-30');
      expect(week.to, today);
      expect(week.length, 7);
      expect(week.canGoForward(today), isFalse);
    });

    test('anterior y siguiente se mueven 7 días sin pasar de hoy', () {
      final current = ProgressPeriod.current(ProgressRange.week, today);
      final previous = current.previous();
      expect((previous.from, previous.to), ('2026-10-23', '2026-10-29'));
      expect(previous.canGoForward(today), isTrue);
      expect(previous.next(today), current);
    });

    test('no se puede ir a un periodo futuro', () {
      final current = ProgressPeriod.current(ProgressRange.week, today);
      expect(current.next(today), current);
    });
  });

  group('mes', () {
    test('el actual va del día 1 a hoy', () {
      final month = ProgressPeriod.current(ProgressRange.month, today);
      expect((month.from, month.to), ('2026-11-01', today));
      expect(month.canGoForward(today), isFalse);
    });

    test('el anterior es el mes completo, también en febrero', () {
      final october = ProgressPeriod.current(
        ProgressRange.month,
        today,
      ).previous();
      expect((october.from, october.to), ('2026-10-01', '2026-10-31'));
      expect(october.length, 31);

      final february = ProgressPeriod.current(
        ProgressRange.month,
        '2026-03-10',
      ).previous();
      expect((february.from, february.to), ('2026-02-01', '2026-02-28'));
    });

    test('el siguiente de un mes pasado llega hasta hoy si es el actual', () {
      final october = ProgressPeriod.current(
        ProgressRange.month,
        today,
      ).previous();
      final november = october.next(today);
      expect((november.from, november.to), ('2026-11-01', today));
    });

    test('cambia de año', () {
      final december = ProgressPeriod.current(
        ProgressRange.month,
        '2027-01-15',
      ).previous();
      expect((december.from, december.to), ('2026-12-01', '2026-12-31'));
    });
  });
}
