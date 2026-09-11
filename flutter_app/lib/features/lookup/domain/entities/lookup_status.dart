/// Mirrors the `status` column on the Rails `Lookup` model.
enum LookupStatus {
  /// The vendor was resolved.
  found,

  /// The vendor API answered but doesn't recognize this MAC's OUI (or the MAC
  /// is a locally administered / randomized address, which has no vendor).
  unknown,

  /// Every vendor provider failed (timeout, rate limit, etc.); the lookup was
  /// still recorded so it shows up in history.
  error;

  static LookupStatus fromApi(String value) => switch (value) {
        'found' => LookupStatus.found,
        'unknown' => LookupStatus.unknown,
        'error' => LookupStatus.error,
        _ => LookupStatus.error,
      };
}
