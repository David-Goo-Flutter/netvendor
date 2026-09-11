/// Everything `LookupRepository` can throw. Kept in the domain layer so
/// `presentation` can show a specific message without knowing whether the
/// failure came from the ARP table, this machine's network stack, or the API.
sealed class LookupException implements Exception {
  final String message;
  const LookupException(this.message);

  @override
  String toString() => message;
}

class InvalidIpAddressException extends LookupException {
  InvalidIpAddressException(String ipAddress) : super('"$ipAddress" is not a valid IPv4 address.');
}

/// The IP isn't in the local ARP table -- this machine has never talked to it,
/// or its entry expired.
class ArpEntryNotFoundException extends LookupException {
  ArpEntryNotFoundException(String ipAddress)
      : super(
          '$ipAddress is not visible on the local network. '
          'It may be offline, or this machine may not have communicated with it recently '
          '(try pinging it first so the OS learns its MAC address).',
        );
}

/// The ARP command itself could not be run or parsed.
class ArpUnavailableException extends LookupException {
  ArpUnavailableException(String reason) : super('Could not read the local ARP table: $reason');
}

/// The NetVendor API request failed -- network error, or an error response.
class LookupRequestFailedException extends LookupException {
  LookupRequestFailedException(super.message);
}
