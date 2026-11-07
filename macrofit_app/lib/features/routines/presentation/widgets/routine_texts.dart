import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';

/// Etiquetas en español de los valores del catálogo (TEC-09). Un valor que la
/// app aún no conoce se muestra tal cual.
String muscleGroupLabel(String apiValue) => switch (apiValue) {
  'chest' => 'Pecho',
  'back' => 'Espalda',
  'legs' => 'Piernas',
  'shoulders' => 'Hombros',
  'arms' => 'Brazos',
  'core' => 'Core',
  _ => apiValue,
};

String levelLabel(String apiValue) => switch (apiValue) {
  'beginner' => 'Principiante',
  'intermediate' => 'Intermedio',
  'advanced' => 'Avanzado',
  _ => apiValue,
};

String equipmentLabel(String apiValue) => switch (apiValue) {
  'bodyweight' => 'Peso corporal',
  'dumbbell' => 'Mancuernas',
  'barbell' => 'Barra',
  'band' => 'Banda elástica',
  'cable' => 'Polea',
  'machine' => 'Máquina',
  'kettlebell' => 'Pesa rusa',
  _ => apiValue,
};

String muscleGroupFilterLabel(MuscleGroup group) =>
    muscleGroupLabel(group.apiValue);

String levelFilterLabel(ExerciseLevel level) => levelLabel(level.apiValue);

/// «Pecho · Mancuernas · Principiante».
String exerciseDetailsText(Exercise exercise) => [
  muscleGroupLabel(exercise.muscleGroup),
  if (exercise.equipment.isNotEmpty) equipmentLabel(exercise.equipment),
  if (exercise.level.isNotEmpty) levelLabel(exercise.level),
].join(' · ');

/// «3 ejercicios · Pecho, Espalda» (grupos sin repetir, en orden de aparición).
String routineSummaryText(Routine routine) {
  final count = routine.exercises.length;
  final exercises = count == 1 ? '1 ejercicio' : '$count ejercicios';
  final groups = <String>{
    for (final exercise in routine.exercises)
      muscleGroupLabel(exercise.muscleGroup),
  };
  return groups.isEmpty ? exercises : '$exercises · ${groups.join(', ')}';
}

/// «6/11/2026» en hora de México (UTC−6), el mismo día que ve el cliente.
String assignedDateText(DateTime assignedAt) {
  final local = assignedAt.toUtc().subtract(const Duration(hours: 6));
  return '${local.day}/${local.month}/${local.year}';
}

/// «1 cliente» / «3 clientes».
String clientCountText(int count) =>
    count == 1 ? '1 cliente' : '$count clientes';
