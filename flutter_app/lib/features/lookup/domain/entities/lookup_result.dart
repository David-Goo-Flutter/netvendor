import 'lookup_status.dart';

/// The outcome of resolving one IP address to a MAC and vendor, as returned by
/// `POST /lookups`.
class LookupResult {
  final int id;
  final String ipAddress;
  final String macAddress;
  final String? vendor;
  final LookupStatus status;
  final DateTime createdAt;

  /// True when the vendor came from a previous lookup of the same MAC rather
  /// than a fresh call to an external vendor API.
  final bool cached;

  const LookupResult({
    required this.id,
    required this.ipAddress,
    required this.macAddress,
    required this.vendor,
    required this.status,
    required this.createdAt,
    required this.cached,
  });
}
