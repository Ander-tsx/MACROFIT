/// Entidad de dominio de la vinculación con el coach (HU-13, HU-14).
class CoachLink {
  const CoachLink({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.coachEmail,
    required this.status,
  });

  final String id;
  final String coachId;
  final String coachName;
  final String coachEmail;
  final String status;
}
