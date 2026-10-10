import '../../domain/entities/coach_client.dart';

class CoachClientModel extends CoachClient {
  const CoachClientModel({
    required super.id,
    required super.name,
    required super.email,
  });

  factory CoachClientModel.fromJson(Map<String, dynamic> json) =>
      CoachClientModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );
}
