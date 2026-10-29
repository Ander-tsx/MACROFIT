import '../entities/coach_link.dart';

abstract class CoachLinkRepository {
  Future<CoachLink?> getLinkedCoach();
  Future<CoachLink> linkCoach(String inviteCode);
  Future<void> unlinkCoach();
}
