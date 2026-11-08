/// Sesión de una rutina que el usuario marcó como completada (HU-17).
class CompletedSession {
  const CompletedSession({
    required this.id,
    required this.routineId,
    required this.sessionNumber,
    required this.sessionName,
    required this.date,
    required this.completedAt,
  });

  final String id;
  final String routineId;
  final int sessionNumber;
  final String sessionName;

  /// Día de cumplimiento `YYYY-MM-DD` en hora de México (como lo guarda la API).
  final String date;
  final DateTime completedAt;
}
