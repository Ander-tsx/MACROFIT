import '../../domain/entities/routine_assignment.dart';

/// Elemento de `/coach/routines/{id}/assignments` (HU-19), en POST y GET.
class RoutineAssignmentModel extends RoutineAssignment {
  const RoutineAssignmentModel({
    required super.id,
    required super.routineId,
    required super.clientId,
    required super.clientName,
    required super.assignedAt,
  });

  factory RoutineAssignmentModel.fromJson(Map<String, dynamic> json) =>
      RoutineAssignmentModel(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        clientId: json['client_id'] as String,
        clientName: json['client_name'] as String,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
      );
}

/// Cuerpo de `POST /coach/routines/{id}/assignments`.
abstract final class AssignRoutineRequestModel {
  static Map<String, dynamic> toJson(List<String> clientIds) => {
    'client_ids': clientIds,
  };
}
