import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../../domain/entities/privacy_notice.dart';

/// Endpoints públicos de documentos legales.
class LegalRemoteDataSource {
  const LegalRemoteDataSource(this._dio);

  final Dio _dio;

  /// TEC-07 — `GET /legal/privacy` → `{ version, content }`.
  Future<PrivacyNotice> getPrivacyNotice() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/legal/privacy');
    final json = response.data!;
    return PrivacyNotice(
      version: json['version'] as String,
      content: json['content'] as String,
    );
  });
}
