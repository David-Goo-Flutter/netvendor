import 'dart:io';

/// Auto-detects this machine's own IPv4 address, to pre-fill the input field.
class NetworkInterfaceDatasource {
  /// Returns the first active, non-loopback IPv4 address found, preferring a
  /// real LAN address over a link-local (169.254.x.x / APIPA) one. Returns
  /// null if the machine has no IPv4 interface up (never throws).
  Future<String?> firstActiveIPv4Address() async {
    List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
    } on SocketException {
      return null;
    }

    String? linkLocalFallback;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;

        if (_isLinkLocal(address.address)) {
          linkLocalFallback ??= address.address;
          continue;
        }
        return address.address;
      }
    }
    return linkLocalFallback;
  }

  bool _isLinkLocal(String ipv4) => ipv4.startsWith('169.254.');
}
