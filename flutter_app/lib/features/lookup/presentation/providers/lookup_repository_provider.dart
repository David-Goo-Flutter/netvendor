import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../data/datasources/arp_local_datasource.dart';
import '../../data/datasources/lookup_remote_datasource.dart';
import '../../data/datasources/network_interface_datasource.dart';
import '../../data/repositories/lookup_repository_impl.dart';
import '../../domain/repositories/lookup_repository.dart';

/// Wires up `LookupRepositoryImpl` from its datasources. Tests override this
/// provider with a mock `LookupRepository` -- nothing downstream needs to
/// know the real implementation exists.
final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  final dio = ref.watch(dioProvider);

  return LookupRepositoryImpl(
    arpLocalDatasource: ArpLocalDatasource(),
    networkInterfaceDatasource: NetworkInterfaceDatasource(),
    lookupRemoteDatasource: LookupRemoteDatasource(dio),
  );
});
