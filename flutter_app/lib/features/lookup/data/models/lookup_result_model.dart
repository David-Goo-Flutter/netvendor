import '../../domain/entities/lookup_result.dart';
import '../../domain/entities/lookup_status.dart';

/// `fromJson`/`toEntity` for the response body of `POST /lookups`:
/// `{ id, ip_address, mac_address, vendor, status, created_at, cached }`.
class LookupResultModel {
  final int id;
  final String ipAddress;
  final String macAddress;
  final String? vendor;
  final String status;
  final DateTime createdAt;
  final bool cached;

  const LookupResultModel({
    required this.id,
    required this.ipAddress,
    required this.macAddress,
    required this.vendor,
    required this.status,
    required this.createdAt,
    required this.cached,
  });

  factory LookupResultModel.fromJson(Map<String, dynamic> json) => LookupResultModel(
        id: json['id'] as int,
        ipAddress: json['ip_address'] as String,
        macAddress: json['mac_address'] as String,
        vendor: json['vendor'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        cached: json['cached'] as bool? ?? false,
      );

  LookupResult toEntity() => LookupResult(
        id: id,
        ipAddress: ipAddress,
        macAddress: macAddress,
        vendor: vendor,
        status: LookupStatus.fromApi(status),
        createdAt: createdAt,
        cached: cached,
      );
}
