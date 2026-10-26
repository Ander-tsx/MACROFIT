import '../../domain/entities/meal_estimate.dart';

/// Cantidad con a lo más un decimal: `413`, `42.2`.
String formatAmount(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// `413 kcal · P 42.2 g · G 4.9 g`. Usa espacios sin corte (` `) para
/// que una línea nunca termine en `G` y deje `4.9 g` en la siguiente.
String mealValuesText(NutritionValues values) =>
    '${formatAmount(values.caloriesKcal)} kcal · '
    'P ${formatAmount(values.proteinG)} g · '
    'G ${formatAmount(values.fatG)} g';
