/// Data-layer failures from calling the NetVendor Rails API. `LookupRepositoryImpl`
/// catches these and rethrows the domain's `LookupRequestFailedException`.
sealed class LookupApiException implements Exception {
  final String message;
  const LookupApiException(this.message);

  @override
  String toString() => message;
}

/// Couldn't reach the API at all (connection refused/timeout/DNS failure).
class LookupApiUnreachableException extends LookupApiException {
  const LookupApiUnreachableException(super.message);
}

/// The API responded with `{ error: { code, message } }`.
class LookupApiRequestException extends LookupApiException {
  final String code;
  const LookupApiRequestException({required this.code, required String message}) : super(message);
}
