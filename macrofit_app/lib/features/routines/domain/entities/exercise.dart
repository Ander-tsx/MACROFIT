/// Grupo muscular del catálogo de ejercicios (TEC-09). Su `name` es el valor de
/// `muscle_group` en la API.
enum MuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core;

  /// Valor que espera y devuelve la API.
  String get apiValue => name;
}

/// Nivel de un ejercicio del catálogo (TEC-09). Su `name` es el valor de `level`
/// en la API.
enum ExerciseLevel {
  beginner,
  intermediate,
  advanced;

  /// Valor que espera y devuelve la API.
  String get apiValue => name;
}

/// Ejercicio del catálogo (`GET /exercises`, TEC-09).
///
/// `muscleGroup`, `equipment` y `level` guardan el valor de la API tal cual
/// (`chest`, `dumbbell`, `beginner`): así un valor nuevo del catálogo no rompe la
/// app; la presentación los traduce para mostrarlos.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.level,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String level;

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.muscleGroup == muscleGroup &&
      other.equipment == equipment &&
      other.level == level;

  @override
  int get hashCode => Object.hash(id, name, muscleGroup, equipment, level);
}
