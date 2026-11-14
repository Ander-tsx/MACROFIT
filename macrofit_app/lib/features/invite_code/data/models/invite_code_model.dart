/// Respuesta de `GET /coach/invite-code` y `POST /coach/invite-code/regenerate`:
/// `{ "code": "K7P2QX" }`.
class InviteCodeModel {
  const InviteCodeModel({required this.code});

  factory InviteCodeModel.fromJson(Map<String, dynamic> json) =>
      InviteCodeModel(code: json['code'] as String);

  final String code;

  Map<String, dynamic> toJson() => {'code': code};

  String toEntity() => code;
}
