import 'package:dio/dio.dart';

import '../exceptions/lookup_api_exception.dart';
import '../models/lookup_result_model.dart';
import '../models/recent_lookup_model.dart';

/// Talks to the Rails API. Only the two endpoints the desktop app actually
/// uses -- `POST /lookups` and `GET /lookups` (history) -- not the read-only
/// `GET /lookups?mac=` wrapper, which exists for other API consumers.
class LookupRemoteDatasource {
  final Dio _dio;
  const LookupRemoteDatasource(this._dio);

  Future<LookupResultModel> createLookup({required String ipAddress, required String macAddress}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lookups',
        data: {'ip_address': ipAddress, 'mac_address': macAddress},
      );
      return LookupResultModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<RecentLookupModel>> fetchRecent({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lookups',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      final lookups = (response.data!['lookups'] as List).cast<Map<String, dynamic>>();
      return lookups.map(RecentLookupModel.fromJson).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  LookupApiException _mapError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      return LookupApiRequestException(
        code: error['code']?.toString() ?? 'unknown_error',
        message: error['message']?.toString() ?? 'The request failed.',
      );
    }

    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        LookupApiUnreachableException('Could not reach the NetVendor API. Is the Rails server running?'),
      _ => LookupApiRequestException(code: 'unknown_error', message: e.message ?? 'The request failed.'),
    };
  }
}
