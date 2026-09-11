import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lookup_repository_provider.dart';

/// This machine's own IPv4 address, used once to pre-fill the input field
/// (the user can still edit it before looking up a different IP).
final localIpAddressProvider = FutureProvider<String?>((ref) {
  final repository = ref.watch(lookupRepositoryProvider);
  return repository.detectLocalIpAddress();
});
