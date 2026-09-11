/// MAC address helpers shared by the ARP parser and the API client.
///
/// Mirrors `MacAddress` on the Rails side: everything is normalized to
/// lowercase, colon-separated, zero-padded octets ("aa:bb:0c:dd:ee:ff") before
/// it is compared, displayed, or sent to the API.
library;

final _separated = RegExp(r'^[0-9a-f]{1,2}([:-])(?:[0-9a-f]{1,2}\1){4}[0-9a-f]{1,2}$');

/// Returns the canonical form of [value], or null when it isn't a MAC address.
/// Accepts colon/dash separated octets, with or without zero padding -- macOS
/// `arp -a` prints entries like "0:1a:2b:3:4:5".
String? normalizeMacAddress(String value) {
  final str = value.trim().toLowerCase();
  if (!_separated.hasMatch(str)) return null;

  final octets = str.split(RegExp('[:-]')).map((octet) => octet.padLeft(2, '0'));
  return octets.join(':');
}

bool isValidMacAddress(String value) => normalizeMacAddress(value) != null;
