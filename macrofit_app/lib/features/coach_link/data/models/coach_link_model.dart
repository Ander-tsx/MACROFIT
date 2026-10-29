import '../../domain/entities/coach_link.dart';

/// Modelo de la vinculación con el coach (HU-13, HU-14).
class CoachLinkModel {
  const CoachLinkModel({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.coachEmail,
    required this.status,
  });

  factory CoachLinkModel.fromJson(Map<String, dynamic> json) {
    return CoachLinkModel(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      coachName: json['coach_name'] as String,
      coachEmail: json['coach_email'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String coachId;
  final String coachName;
  final String coachEmail;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'coach_id': coachId,
    'coach_name': coachName,
    'coach_email': coachEmail,
    'status': status,
  };

  CoachLink toEntity() => CoachLink(
    id: id,
    coachId: coachId,
    coachName: coachName,
    coachEmail: coachEmail,
    status: status,
  );
}
