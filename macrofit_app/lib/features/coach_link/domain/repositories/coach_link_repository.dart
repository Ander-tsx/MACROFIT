import '../../data/models/coach_link_model.dart';

abstract class CoachLinkRepository {
  Future<CoachLinkModel> linkCoach(String inviteCode);
  Future<void> unlinkCoach();
}
