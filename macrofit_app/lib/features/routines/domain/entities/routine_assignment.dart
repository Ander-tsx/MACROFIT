/// Rutina de un coach asignada a un cliente vinculado (HU-19, RF-23).
class RoutineAssignment {
  const RoutineAssignment({
    required this.id,
    required this.routineId,
    required this.clientId,
    required this.clientName,
    required this.assignedAt,
  });

  final String id;
  final String routineId;
  final String clientId;
  final String clientName;

  /// Cuándo se asignó por primera vez (no cambia al volver a asignarla).
  final DateTime assignedAt;

  @override
  bool operator ==(Object other) =>
      other is RoutineAssignment &&
      other.id == id &&
      other.routineId == routineId &&
      other.clientId == clientId &&
      other.clientName == clientName &&
      other.assignedAt == assignedAt;

  @override
  int get hashCode =>
      Object.hash(id, routineId, clientId, clientName, assignedAt);
}
