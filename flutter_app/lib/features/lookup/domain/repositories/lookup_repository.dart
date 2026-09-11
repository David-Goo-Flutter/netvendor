import '../entities/lookup_result.dart';
import '../entities/recent_lookup.dart';

/// Domain-facing entry point for the lookup feature. Knows nothing about ARP,
/// Dio, or the Rails API -- just what the app can ask for and what can go
/// wrong (see `lookup_exceptions.dart`).
abstract class LookupRepository {
  /// This machine's first active, non-loopback IPv4 address, or null if none
  /// is found. Used to pre-fill the input field; never throws.
  Future<String?> detectLocalIpAddress();

  /// Resolves [ipAddress] to a MAC address via the local ARP table, then asks
  /// the NetVendor API for its vendor. The result is persisted server-side.
  ///
  /// Throws [InvalidIpAddressException], [ArpEntryNotFoundException],
  /// [ArpUnavailableException], or [LookupRequestFailedException].
  Future<LookupResult> lookup(String ipAddress);

  /// Lookup history from the NetVendor API, newest first.
  ///
  /// Throws [LookupRequestFailedException].
  Future<List<RecentLookup>> fetchRecentLookups();
}
