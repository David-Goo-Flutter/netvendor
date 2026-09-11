import 'lookup_status.dart';

/// One row of lookup history, as returned by `GET /lookups`.
class RecentLookup {
  final int id;
  final String ipAddress;
  final String macAddress;
  final String? vendor;
  final LookupStatus status;
  final DateTime createdAt;

  const RecentLookup({
    required this.id,
    required this.ipAddress,
    required this.macAddress,
    required this.vendor,
    required this.status,
    required this.createdAt,
  });
}
