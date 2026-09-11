import '../../../../utils/ip_address.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/entities/recent_lookup.dart';
import '../../domain/exceptions/lookup_exceptions.dart';
import '../../domain/repositories/lookup_repository.dart';
import '../datasources/arp_local_datasource.dart';
import '../datasources/lookup_remote_datasource.dart';
import '../datasources/network_interface_datasource.dart';
import '../exceptions/lookup_api_exception.dart';

/// Composes the ARP, network-interface, and remote datasources into the
/// domain's `LookupRepository`, translating each datasource's own
/// exceptions into the domain's `LookupException` hierarchy.
class LookupRepositoryImpl implements LookupRepository {
  final ArpLocalDatasource _arpLocalDatasource;
  final NetworkInterfaceDatasource _networkInterfaceDatasource;
  final LookupRemoteDatasource _lookupRemoteDatasource;

  const LookupRepositoryImpl({
    required ArpLocalDatasource arpLocalDatasource,
    required NetworkInterfaceDatasource networkInterfaceDatasource,
    required LookupRemoteDatasource lookupRemoteDatasource,
  })  : _arpLocalDatasource = arpLocalDatasource,
        _networkInterfaceDatasource = networkInterfaceDatasource,
        _lookupRemoteDatasource = lookupRemoteDatasource;

  @override
  Future<String?> detectLocalIpAddress() => _networkInterfaceDatasource.firstActiveIPv4Address();

  @override
  Future<LookupResult> lookup(String ipAddress) async {
    final ip = ipAddress.trim();
    if (!isValidIPv4Address(ip)) throw InvalidIpAddressException(ip);

    final String? macAddress;
    try {
      macAddress = await _arpLocalDatasource.findMacAddress(ip);
    } on ArpProcessException catch (e) {
      throw ArpUnavailableException(e.message);
    }
    if (macAddress == null) throw ArpEntryNotFoundException(ip);

    try {
      final model = await _lookupRemoteDatasource.createLookup(ipAddress: ip, macAddress: macAddress);
      return model.toEntity();
    } on LookupApiException catch (e) {
      throw LookupRequestFailedException(e.message);
    }
  }

  @override
  Future<List<RecentLookup>> fetchRecentLookups() async {
    try {
      final models = await _lookupRemoteDatasource.fetchRecent();
      return models.map((model) => model.toEntity()).toList();
    } on LookupApiException catch (e) {
      throw LookupRequestFailedException(e.message);
    }
  }
}
