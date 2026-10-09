class ProfileNotFoundException implements Exception {
  final String message;
  const ProfileNotFoundException([this.message = 'Perfil no encontrado']);
  @override
  String toString() => 'ProfileNotFoundException: $message';
}

class GoalsForbiddenException implements Exception {
  final String message;
  const GoalsForbiddenException([this.message = 'Acceso denegado']);
  @override
  String toString() => 'GoalsForbiddenException: $message';
}

class GoalsServerException implements Exception {
  final int? statusCode;
  final String message;
  const GoalsServerException(this.message, [this.statusCode]);
  @override
  String toString() => 'GoalsServerException($statusCode): $message';
}
