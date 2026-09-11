import 'dart:io';

import '../../../../utils/mac_address.dart';

/// One "IP is at MAC" line from `arp -a`.
class ArpEntry {
  final String ipAddress;
  final String macAddress;
  const ArpEntry({required this.ipAddress, required this.macAddress});
}

// Both platforms print "(<ip>) at <mac-or-"(incomplete)">" somewhere in the line:
//   macOS:  ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
//   Linux:  host (192.168.1.1) at aa:bb:cc:dd:ee:ff [ether] on eth0
// An entry the OS hasn't resolved yet reads "at (incomplete)" -- normalizeMacAddress
// rejects that token, so it's naturally skipped below rather than needing its own case.
final _entryPattern = RegExp(r'\((\d{1,3}(?:\.\d{1,3}){3})\)\s+at\s+(\S+)');

/// Parses `arp -a` output into entries with a resolved MAC address. Kept as a
/// pure function, separate from [ArpLocalDatasource.findMacAddress], so the
/// parsing logic is unit-testable without spawning a process.
List<ArpEntry> parseArpOutput(String raw) {
  final entries = <ArpEntry>[];

  for (final match in _entryPattern.allMatches(raw)) {
    final mac = normalizeMacAddress(match.group(2)!);
    if (mac == null) continue; // e.g. "(incomplete)"

    entries.add(ArpEntry(ipAddress: match.group(1)!, macAddress: mac));
  }

  return entries;
}

/// Looks up a MAC address for a given IPv4 address via the OS's ARP table.
class ArpLocalDatasource {
  /// Returns the MAC address [ipAddress] resolves to, or null if there's no
  /// entry for it (the IP hasn't been seen on the local network recently).
  Future<String?> findMacAddress(String ipAddress) async {
    final ProcessResult result;
    try {
      result = await Process.run('arp', ['-a']);
    } on ProcessException catch (e) {
      throw ArpProcessException("couldn't run `arp -a`: ${e.message}");
    }

    if (result.exitCode != 0) {
      throw ArpProcessException('`arp -a` exited with code ${result.exitCode}: ${result.stderr}');
    }

    final entries = parseArpOutput(result.stdout as String);
    for (final entry in entries) {
      if (entry.ipAddress == ipAddress) return entry.macAddress;
    }
    return null;
  }
}

/// Running or parsing `arp -a` itself failed -- distinct from a clean "no
/// entry for this IP" result. Data-layer only; `LookupRepositoryImpl` maps it
/// to the domain's `ArpUnavailableException`.
class ArpProcessException implements Exception {
  final String message;
  const ArpProcessException(this.message);

  @override
  String toString() => message;
}
