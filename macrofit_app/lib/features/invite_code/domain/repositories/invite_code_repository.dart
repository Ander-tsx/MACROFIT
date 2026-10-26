/// Código de invitación del coach de la sesión (HU-12). Los clientes lo usan para
/// vincularse con él (HU-13). Los métodos lanzan `ApiException` ante errores de la
/// API o de red.
abstract interface class InviteCodeRepository {
  /// `GET /coach/invite-code`: el código actual (6 caracteres `A-Z0-9`).
  /// Si el coach aún no tiene uno, el servidor lo crea.
  Future<String> getInviteCode();

  /// `POST /coach/invite-code/regenerate`: un código nuevo, siempre distinto al
  /// anterior, que deja de ser válido. Las vinculaciones existentes no cambian.
  Future<String> regenerateInviteCode();
}
