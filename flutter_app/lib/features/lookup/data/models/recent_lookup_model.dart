import '../../domain/entities/lookup_status.dart';
import '../../domain/entities/recent_lookup.dart';

/// `fromJson`/`toEntity` for one entry of `GET /lookups`'s `lookups` array:
/// `{ id, ip_address, mac_address, vendor, status, created_at }`.
class RecentLookupModel {
  final int id;
  final String ipAddress;
  final String macAddress;
  final String? vendor;
  final String status;
  final DateTime createdAt;

  const RecentLookupModel({
    required this.id,
    required this.ipAddress,
    required this.macAddress,
    required this.vendor,
    required this.status,
    required this.createdAt,
  });

  factory RecentLookupModel.fromJson(Map<String, dynamic> json) => RecentLookupModel(
        id: json['id'] as int,
        ipAddress: json['ip_address'] as String,
        macAddress: json['mac_address'] as String,
        vendor: json['vendor'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  RecentLookup toEntity() => RecentLookup(
        id: id,
        ipAddress: ipAddress,
        macAddress: macAddress,
        vendor: vendor,
        status: LookupStatus.fromApi(status),
        createdAt: createdAt,
      );
}
