import '../../../../core/errors/api_exception.dart';
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

String _two(int value) => value.toString().padLeft(2, '0');

/// Hora local del registro: `19:30`.
String mealTimeText(DateTime eatenAt) {
  final local = eatenAt.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// Día elegido: `Hoy`, `Ayer` o `17/10/2026`.
String dayLabel(DateTime day, {required DateTime now}) {
  final date = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (today.difference(date).inDays) {
    0 => 'Hoy',
    1 => 'Ayer',
    _ => '${_two(date.day)}/${_two(date.month)}/${date.year}',
  };
}

/// HU-09 — mensajes en español de los errores de la foto al guardar
/// (`POST /meals`); los demás errores usan el mensaje de la API.
abstract final class MealSaveMessages {
  static const photoAlreadyUsed =
      'Esta foto ya está en otro registro. Vuelve a registrar la comida con '
      'otra foto o captura los valores sin foto.';
  static const photoNotFound =
      'No encontramos la foto de este registro. Vuelve a tomarla o captura '
      'los valores sin foto.';

  static String of(ApiException error) => switch (error.code) {
    ApiErrorCode.photoAlreadyUsed => photoAlreadyUsed,
    ApiErrorCode.photoNotFound => photoNotFound,
    _ => error.message,
  };
}
