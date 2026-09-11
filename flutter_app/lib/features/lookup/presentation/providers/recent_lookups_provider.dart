import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recent_lookup.dart';
import 'lookup_repository_provider.dart';

/// Recent lookup history, sourced from `GET /lookups`. The refresh button in
/// `RecentLookupsList` calls `ref.invalidate(recentLookupsProvider)`; a
/// successful new lookup does the same so the list stays current.
final recentLookupsProvider = FutureProvider<List<RecentLookup>>((ref) {
  final repository = ref.watch(lookupRepositoryProvider);
  return repository.fetchRecentLookups();
});
