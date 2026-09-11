import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netvendor/features/lookup/data/datasources/arp_local_datasource.dart';
import 'package:netvendor/features/lookup/data/datasources/lookup_remote_datasource.dart';
import 'package:netvendor/features/lookup/data/datasources/network_interface_datasource.dart';
import 'package:netvendor/features/lookup/data/exceptions/lookup_api_exception.dart';
import 'package:netvendor/features/lookup/data/models/lookup_result_model.dart';
import 'package:netvendor/features/lookup/data/models/recent_lookup_model.dart';
import 'package:netvendor/features/lookup/data/repositories/lookup_repository_impl.dart';
import 'package:netvendor/features/lookup/domain/entities/lookup_status.dart';
import 'package:netvendor/features/lookup/domain/exceptions/lookup_exceptions.dart';

class _MockArpLocalDatasource extends Mock implements ArpLocalDatasource {}

class _MockNetworkInterfaceDatasource extends Mock implements NetworkInterfaceDatasource {}

class _MockLookupRemoteDatasource extends Mock implements LookupRemoteDatasource {}

void main() {
  late _MockArpLocalDatasource arp;
  late _MockNetworkInterfaceDatasource networkInterface;
  late _MockLookupRemoteDatasource remote;
  late LookupRepositoryImpl repository;

  setUp(() {
    arp = _MockArpLocalDatasource();
    networkInterface = _MockNetworkInterfaceDatasource();
    remote = _MockLookupRemoteDatasource();
    repository = LookupRepositoryImpl(
      arpLocalDatasource: arp,
      networkInterfaceDatasource: networkInterface,
      lookupRemoteDatasource: remote,
    );
  });

  group('detectLocalIpAddress', () {
    test('delegates to the network interface datasource', () async {
      when(() => networkInterface.firstActiveIPv4Address()).thenAnswer((_) async => '192.168.1.50');

      expect(await repository.detectLocalIpAddress(), '192.168.1.50');
    });
  });

  group('lookup', () {
    test('rejects an invalid IP without touching ARP or the network', () async {
      await expectLater(repository.lookup('not-an-ip'), throwsA(isA<InvalidIpAddressException>()));

      verifyNever(() => arp.findMacAddress(any()));
      verifyNever(() => remote.createLookup(ipAddress: any(named: 'ipAddress'), macAddress: any(named: 'macAddress')));
    });

    test('throws ArpEntryNotFoundException when the IP has no ARP entry', () async {
      when(() => arp.findMacAddress('192.168.1.1')).thenAnswer((_) async => null);

      await expectLater(repository.lookup('192.168.1.1'), throwsA(isA<ArpEntryNotFoundException>()));
      verifyNever(() => remote.createLookup(ipAddress: any(named: 'ipAddress'), macAddress: any(named: 'macAddress')));
    });

    test('wraps an ARP process failure in ArpUnavailableException', () async {
      when(() => arp.findMacAddress('192.168.1.1')).thenThrow(const ArpProcessException('boom'));

      await expectLater(repository.lookup('192.168.1.1'), throwsA(isA<ArpUnavailableException>()));
    });

    test('resolves the MAC via ARP then maps the API response to a LookupResult entity', () async {
      when(() => arp.findMacAddress('192.168.1.1')).thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => remote.createLookup(ipAddress: '192.168.1.1', macAddress: 'aa:bb:cc:dd:ee:ff')).thenAnswer(
        (_) async => LookupResultModel(
          id: 1,
          ipAddress: '192.168.1.1',
          macAddress: 'aa:bb:cc:dd:ee:ff',
          vendor: 'Arcadyan Corporation',
          status: 'found',
          createdAt: DateTime.utc(2026, 1, 1),
          cached: false,
        ),
      );

      final result = await repository.lookup('192.168.1.1');

      expect(result.ipAddress, '192.168.1.1');
      expect(result.macAddress, 'aa:bb:cc:dd:ee:ff');
      expect(result.vendor, 'Arcadyan Corporation');
      expect(result.status, LookupStatus.found);
      expect(result.cached, isFalse);
    });

    test('wraps a remote API failure in LookupRequestFailedException', () async {
      when(() => arp.findMacAddress('192.168.1.1')).thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => remote.createLookup(ipAddress: any(named: 'ipAddress'), macAddress: any(named: 'macAddress')))
          .thenThrow(const LookupApiUnreachableException('Could not reach the NetVendor API.'));

      await expectLater(repository.lookup('192.168.1.1'), throwsA(isA<LookupRequestFailedException>()));
    });
  });

  group('fetchRecentLookups', () {
    test('maps each model to a RecentLookup entity', () async {
      when(() => remote.fetchRecent()).thenAnswer((_) async => [
            RecentLookupModel(
              id: 1,
              ipAddress: '192.168.1.1',
              macAddress: 'aa:bb:cc:dd:ee:ff',
              vendor: 'Arcadyan Corporation',
              status: 'found',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ]);

      final lookups = await repository.fetchRecentLookups();

      expect(lookups, hasLength(1));
      expect(lookups.single.vendor, 'Arcadyan Corporation');
      expect(lookups.single.status, LookupStatus.found);
    });

    test('wraps a remote API failure in LookupRequestFailedException', () async {
      when(() => remote.fetchRecent())
          .thenThrow(const LookupApiRequestException(code: 'server_error', message: 'boom'));

      await expectLater(repository.fetchRecentLookups(), throwsA(isA<LookupRequestFailedException>()));
    });
  });
}
