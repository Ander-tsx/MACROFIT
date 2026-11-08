import '../../domain/entities/completed_session.dart';

/// Respuesta de `POST` y elemento de `GET /users/me/routines/{id}/sessions`
/// (HU-17): `{ id, routine_id, origin, routine_name, session_number,
/// session_name, date, completed_at }`.
abstract final class CompletedSessionModel {
  static CompletedSession fromJson(Map<String, dynamic> json) =>
      CompletedSession(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        sessionNumber: (json['session_number'] as num).toInt(),
        sessionName: json['session_name'] as String,
        date: json['date'] as String,
        completedAt: DateTime.parse(json['completed_at'] as String),
      );

  /// Cuerpo del `POST`: sin `date`, la API registra hoy (hora de México).
  static Map<String, dynamic> requestJson(int sessionNumber) => {
    'session_number': sessionNumber,
  };
}
