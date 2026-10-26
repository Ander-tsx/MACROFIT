import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/clients/presentation/widgets/client_meal_texts.dart';

void main() {
  test('las cantidades llevan a lo más un decimal', () {
    expect(formatAmount(413), '413');
    expect(formatAmount(42.2), '42.2');
    expect(formatAmount(4.96), '5');
    expect(formatAmount(793.4000000001), '793.4');
    expect(formatAmount(0), '0');
  });

  test('resume calorías, proteína y grasa del registro', () {
    expect(
      mealValuesText(calories: 413, proteinG: 42.2, fatG: 4.9),
      '413 kcal · P 42.2 g · G 4.9 g',
    );
  });

  test('la hora del registro se muestra en hora local', () {
    expect(mealTimeText(DateTime(2026, 10, 16, 9, 5)), '09:05');
    final utc = DateTime.utc(2026, 10, 17, 1, 30);
    final local = utc.toLocal();
    expect(
      mealTimeText(utc),
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}',
    );
  });

  test('el día elegido se nombra hoy, ayer o con su fecha', () {
    final now = DateTime(2026, 10, 25, 20);
    expect(dayLabel(DateTime(2026, 10, 25), now: now), 'Hoy');
    expect(dayLabel(DateTime(2026, 10, 24), now: now), 'Ayer');
    expect(dayLabel(DateTime(2026, 10, 3), now: now), '03/10/2026');
  });
}
