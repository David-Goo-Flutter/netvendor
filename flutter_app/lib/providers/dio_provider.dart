import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Override with `--dart-define=NETVENDOR_API_BASE_URL=http://host:port` to
/// point at a Rails server other than the local default.
const _defaultBaseUrl = 'http://localhost:3000';
const netvendorApiBaseUrl = String.fromEnvironment(
  'NETVENDOR_API_BASE_URL',
  defaultValue: _defaultBaseUrl,
);

/// Single Dio instance for the whole app -- shared across features, so it
/// lives in the root `providers/`, not inside `features/lookup/`.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: netvendorApiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
});
