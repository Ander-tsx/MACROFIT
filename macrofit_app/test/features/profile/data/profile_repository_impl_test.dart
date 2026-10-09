import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:macrofit_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:macrofit_app/features/profile/domain/entities/profile.dart';

import '../../../helpers/fakes.dart';

const _profileJson = {
  'id': '6ac6aa707314ad6c7164900e',
  'user_id': '6ac67c707314ad6c7164900b',
  'objective': 'lose_fat',
  'level': 'beginner',
  'training_days': 4,
  'weight_kg': 72.5,
  'height_cm': 170.0,
  'gender': 'female',
  'birth_date': '1996-05-20',
  'created_at': '2026-10-08T21:40:00Z',
  'updated_at': '2026-10-08T21:40:00Z',
};

void main() {
  late FakeHttpAdapter adapter;

  ProfileRepositoryImpl build(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ProfileRepositoryImpl(ProfileRemoteDataSource(dio));
  }

  Map<String, dynamic> sentBody() {
    final data = adapter.requests.single.data;
    return data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }

  test('consulta el perfil y lo convierte a la entidad', () async {
    final repository = build((_) => jsonResponse(_profileJson, 200));

    final profile = await repository.getProfile();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/users/me/profile');
    expect(profile, testProfile);
  });

  test('crea el perfil con los nombres y valores de la API', () async {
    final repository = build((_) => jsonResponse(_profileJson, 201));

    final profile = await repository.createProfile(testProfile);

    expect(adapter.requests.single.method, 'POST');
    expect(sentBody(), {
      'objective': 'lose_fat',
      'level': 'beginner',
      'training_days': 4,
      'weight_kg': 72.5,
      'height_cm': 170.0,
      'gender': 'female',
      'birth_date': '1996-05-20',
    });
    expect(profile, testProfile);
  });

  test('edita el perfil con PATCH', () async {
    final edited = Profile(
      objective: Objective.gainMuscle,
      level: ExperienceLevel.intermediate,
      trainingDays: 5,
      weightKg: 70.2,
      heightCm: 170,
      gender: Gender.female,
      birthDate: DateTime(1985, 1, 3),
    );
    final repository = build(
      (_) => jsonResponse({
        ..._profileJson,
        'objective': 'gain_muscle',
        'level': 'intermediate',
        'training_days': 5,
        'weight_kg': 70.2,
        'birth_date': '1985-01-03',
      }, 200),
    );

    final profile = await repository.updateProfile(edited);

    expect(adapter.requests.single.method, 'PATCH');
    expect(sentBody()['birth_date'], '1985-01-03');
    expect(profile, edited);
  });

  test('sin perfil llega ApiException PROFILE_NOT_FOUND', () async {
    final repository = build(
      (_) => errorResponse(ApiErrorCode.profileNotFound, 404),
    );

    await expectLater(
      repository.getProfile(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.profileNotFound)
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });
}
