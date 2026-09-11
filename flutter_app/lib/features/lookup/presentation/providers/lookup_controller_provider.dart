import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lookup_result.dart';
import 'lookup_repository_provider.dart';
import 'recent_lookups_provider.dart';

/// Drives the lookup flow for the input field + result card. `null` means "no
/// lookup performed yet" (distinct from `AsyncLoading`/`AsyncError`, which
/// `AsyncNotifier` already gives us for the in-flight and failed states).
final lookupControllerProvider = AsyncNotifierProvider<LookupController, LookupResult?>(LookupController.new);

class LookupController extends AsyncNotifier<LookupResult?> {
  @override
  Future<LookupResult?> build() async => null;

  Future<void> lookup(String ipAddress) async {
    state = const AsyncLoading();
    final repository = ref.read(lookupRepositoryProvider);

    state = await AsyncValue.guard(() => repository.lookup(ipAddress));

    if (!state.hasError) {
      // A new lookup may have changed the vendor/cache status of a MAC
      // already in history, so refresh it rather than trusting the old list.
      ref.invalidate(recentLookupsProvider);
    }
  }
}
