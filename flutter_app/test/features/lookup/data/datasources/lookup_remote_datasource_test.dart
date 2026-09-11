import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netvendor/features/lookup/data/datasources/lookup_remote_datasource.dart';
import 'package:netvendor/features/lookup/data/exceptions/lookup_api_exception.dart';

/// Every other test in this suite mocks `LookupRemoteDatasource` itself, so
/// nothing else exercises its `_mapError` translation from a real Dio
/// response/exception into `LookupApiException`. This file stubs `Dio`
/// directly (a well-established mocktail pattern: `noSuchMethod`-based
/// mocking doesn't care about a method's generic type argument) so those
/// mappings are actually verified against realistic responses.
class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _response(int statusCode, Object? data) => Response(
      requestOptions: RequestOptions(path: '/lookups'),
      statusCode: statusCode,
      data: data as Map<String, dynamic>?,
    );

DioException _error({Response<dynamic>? response, required DioExceptionType type}) => DioException(
      requestOptions: RequestOptions(path: '/lookups'),
      response: response,
      type: type,
    );

void main() {
  late _MockDio dio;
  late LookupRemoteDatasource datasource;

  setUp(() {
    dio = _MockDio();
    datasource = LookupRemoteDatasource(dio);
  });

  group('createLookup', () {
    test('parses a found vendor', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _response(201, {
          'id': 1,
          'ip_address': '192.168.1.1',
          'mac_address': 'aa:bb:cc:dd:ee:ff',
          'vendor': 'Arcadyan Corporation',
          'status': 'found',
          'created_at': '2026-01-01T00:00:00Z',
          'cached': false,
        }),
      );

      final model = await datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff');

      expect(model.vendor, 'Arcadyan Corporation');
      expect(model.status, 'found');
    });

    // "Vendor API down" is not a Dio/HTTP error at all on this endpoint: Rails
    // still records the attempt and answers 201 with status "error" so it
    // shows up in history. Confirms `createLookup` parses that shape as a
    // normal success rather than throwing.
    test('parses a "both vendor providers failed" response as a plain success', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _response(201, {
          'id': 2,
          'ip_address': '192.168.1.1',
          'mac_address': 'aa:bb:cc:dd:ee:ff',
          'vendor': null,
          'status': 'error',
          'created_at': '2026-01-01T00:00:00Z',
          'cached': false,
        }),
      );

      final model = await datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff');

      expect(model.vendor, isNull);
      expect(model.status, 'error');
    });

    test('maps a 422 { error: { code, message } } body to LookupApiRequestException', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenThrow(_error(
        type: DioExceptionType.badResponse,
        response: _response(422, {
          'error': {'code': 'invalid_mac_address', 'message': '"zz" is not a valid MAC address'},
        }),
      ));

      await expectLater(
        datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'zz'),
        throwsA(
          isA<LookupApiRequestException>()
              .having((e) => e.code, 'code', 'invalid_mac_address')
              .having((e) => e.message, 'message', contains('not a valid MAC address')),
        ),
      );
    });

    test('maps a connection failure to LookupApiUnreachableException', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(_error(type: DioExceptionType.connectionError));

      await expectLater(
        datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff'),
        throwsA(isA<LookupApiUnreachableException>().having((e) => e.message, 'message', contains('Rails server'))),
      );
    });

    test('maps a connection timeout to LookupApiUnreachableException', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(_error(type: DioExceptionType.connectionTimeout));

      await expectLater(
        datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff'),
        throwsA(isA<LookupApiUnreachableException>()),
      );
    });

    test('falls back to a generic LookupApiRequestException for an unexpected error body', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenThrow(_error(
        type: DioExceptionType.badResponse,
        response: _response(500, null),
      ));

      await expectLater(
        datasource.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff'),
        throwsA(isA<LookupApiRequestException>().having((e) => e.code, 'code', 'unknown_error')),
      );
    });
  });

  group('fetchRecent', () {
    test('parses the lookups array', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => _response(200, {
          'lookups': [
            {
              'id': 1,
              'ip_address': '192.168.1.1',
              'mac_address': 'aa:bb:cc:dd:ee:ff',
              'vendor': 'Arcadyan Corporation',
              'status': 'found',
              'created_at': '2026-01-01T00:00:00Z',
            },
          ],
          'meta': {'page': 1, 'per_page': 20, 'total_count': 1, 'total_pages': 1},
        }),
      );

      final models = await datasource.fetchRecent();

      expect(models, hasLength(1));
      expect(models.single.vendor, 'Arcadyan Corporation');
    });

    test('maps a server error to LookupApiRequestException', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(_error(type: DioExceptionType.badResponse, response: _response(500, null)));

      await expectLater(datasource.fetchRecent(), throwsA(isA<LookupApiRequestException>()));
    });
  });
}
