import 'user_model.dart';

/// Par de tokens de una sesión.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Respuesta de `POST /auth/login` y `POST /auth/refresh`.
class SessionModel {
  const SessionModel({required this.tokens, required this.user});

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
    tokens: TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    ),
    user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
  );

  final TokenPair tokens;
  final UserModel user;
}
