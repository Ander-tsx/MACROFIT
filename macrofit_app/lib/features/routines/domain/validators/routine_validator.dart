/// Reglas de una rutina del coach (HU-18, RF-22, CU-04 flujo 4a). Deben coincidir
/// con `backend/src/services/routines.rs` (`validate_routine`, `NAME_MAX_CHARS`,
/// `MAX_EXERCISES`, `MAX_SETS`, `MAX_REPS`, `MAX_REST_SECONDS`); los mensajes son
/// los mismos que manda la API. Cada función devuelve el mensaje o `null`.
abstract final class RoutineValidator {
  static const nameMaxChars = 80;
  static const minExercises = 1;
  static const maxExercises = 20;
  static const minSets = 1;
  static const maxSets = 10;
  static const minReps = 1;
  static const maxReps = 100;
  static const minRestSeconds = 0;
  static const maxRestSeconds = 600;

  // Nombres de los campos en la API.
  static const nameField = 'name';
  static const exercisesField = 'exercises';
  static const exerciseIdField = 'exercise_id';
  static const setsField = 'sets';
  static const repsField = 'reps';
  static const restSecondsField = 'rest_seconds';

  /// Campo de un ejercicio como lo señala la API: `exercises[0].sets`.
  static String exerciseField(int index, String field) =>
      '$exercisesField[$index].$field';

  /// El servidor recorta el nombre; aquí se cuenta igual.
  static String? name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'El nombre es obligatorio';
    if (trimmed.runes.length > nameMaxChars) {
      return 'El nombre debe tener máximo $nameMaxChars caracteres';
    }
    return null;
  }

  static String? exerciseCount(int count) {
    if (count < minExercises) {
      return 'La rutina debe tener al menos un ejercicio';
    }
    if (count > maxExercises) {
      return 'La rutina puede tener máximo $maxExercises ejercicios';
    }
    return null;
  }

  static String? sets(String value) => _integer(
    value,
    min: minSets,
    max: maxSets,
    missing: 'Las series son obligatorias',
    notInteger: 'Las series deben ser un número entero',
    outOfRange: 'Las series deben estar entre $minSets y $maxSets',
  );

  static String? reps(String value) => _integer(
    value,
    min: minReps,
    max: maxReps,
    missing: 'Las repeticiones son obligatorias',
    notInteger: 'Las repeticiones deben ser un número entero',
    outOfRange: 'Las repeticiones deben estar entre $minReps y $maxReps',
  );

  static String? restSeconds(String value) => _integer(
    value,
    min: minRestSeconds,
    max: maxRestSeconds,
    missing: 'El descanso es obligatorio',
    notInteger: 'El descanso debe ser un número entero de segundos',
    outOfRange:
        'El descanso debe estar entre $minRestSeconds y $maxRestSeconds segundos',
  );

  /// Entero del campo (signo opcional y espacios alrededor); `null` si no lo es.
  static int? parseInt(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^-?\d+$').hasMatch(trimmed)) return null;
    return int.tryParse(trimmed);
  }

  /// Valida la rutina completa y devuelve **todos** los errores, con los nombres de
  /// campo de la API (`name`, `exercises`, `exercises[i].sets`...). Vacío = válida.
  static Map<String, String> validate({
    required String name,
    required List<({String sets, String reps, String restSeconds})> exercises,
  }) {
    final errors = <String, String>{};
    void add(String field, String? message) {
      if (message != null) errors[field] = message;
    }

    add(nameField, RoutineValidator.name(name));
    add(exercisesField, exerciseCount(exercises.length));
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      add(exerciseField(i, setsField), sets(exercise.sets));
      add(exerciseField(i, repsField), reps(exercise.reps));
      add(
        exerciseField(i, restSecondsField),
        restSeconds(exercise.restSeconds),
      );
    }
    return errors;
  }

  static String? _integer(
    String value, {
    required int min,
    required int max,
    required String missing,
    required String notInteger,
    required String outOfRange,
  }) {
    if (value.trim().isEmpty) return missing;
    final number = parseInt(value);
    if (number == null) return notInteger;
    if (number < min || number > max) return outOfRange;
    return null;
  }
}
