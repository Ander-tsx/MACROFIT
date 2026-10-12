/// Rol de la cuenta. Su `name` coincide con el valor de la API (`"user"` / `"coach"`).
enum Role {
  user('Usuario'),
  coach('Coach');

  const Role(this.label);

  /// Texto para mostrar.
  final String label;

  /// Valor que espera y devuelve la API.
  String get apiValue => name;

  static Role fromApi(String value) => Role.values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => throw FormatException('Rol desconocido: $value'),
  );
}
