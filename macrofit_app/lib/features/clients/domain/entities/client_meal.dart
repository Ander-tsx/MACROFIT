/// Registro de comida de un cliente, visto por su coach (HU-25). Solo lectura (RN-07).
class ClientMeal {
  const ClientMeal({
    required this.id,
    required this.eatenAt,
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
    this.photoUrl,
  });

  final String id;

  /// Ruta para descargar la foto con la sesión del coach; `null` en una captura manual.
  final String? photoUrl;

  /// Fecha y hora del registro (la pone el servidor, en UTC).
  final DateTime eatenAt;

  final double caloriesKcal;
  final double proteinG;
  final double fatG;
}
