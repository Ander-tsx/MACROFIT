import '../entities/coach_link.dart';

abstract class CoachLinkRepository {
  Future<CoachLink?> getLinkedCoach();

  /// Nombre del coach dueño de [inviteCode], sin vincular (CU-02 paso 4).
  Future<String> previewCoach(String inviteCode);
  Future<CoachLink> linkCoach(String inviteCode);
  Future<void> unlinkCoach();
}
