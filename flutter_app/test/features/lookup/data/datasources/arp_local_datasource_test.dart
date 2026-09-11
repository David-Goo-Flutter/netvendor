import 'package:flutter_test/flutter_test.dart';
import 'package:netvendor/features/lookup/data/datasources/arp_local_datasource.dart';

void main() {
  group('parseArpOutput', () {
    test('parses macOS `arp -a` output', () {
      const raw = '''
? (169.254.169.254) at (incomplete) on en0 [ethernet]
tmo-g4ar.lan (192.168.12.1) at 18:a5:ff:45:44:28 on en0 ifscope [ethernet]
? (192.168.12.123) at 92:90:ae:e9:5f:6b on en0 ifscope [ethernet]
junhyuks-air.lan (192.168.12.126) at 14:7d:da:77:d3:a9 on en0 ifscope [ethernet]
''';

      final entries = parseArpOutput(raw);

      expect(entries, hasLength(3));
      expect(entries[0].ipAddress, '192.168.12.1');
      expect(entries[0].macAddress, '18:a5:ff:45:44:28');
      expect(entries[2].ipAddress, '192.168.12.126');
      expect(entries[2].macAddress, '14:7d:da:77:d3:a9');
    });

    test('skips incomplete entries', () {
      const raw = '? (169.254.169.254) at (incomplete) on en0 [ethernet]';

      expect(parseArpOutput(raw), isEmpty);
    });

    test('parses Linux `arp -a` output', () {
      const raw = 'router.lan (192.168.1.1) at aa:bb:cc:dd:ee:ff [ether] on eth0';

      final entries = parseArpOutput(raw);

      expect(entries, hasLength(1));
      expect(entries.single.ipAddress, '192.168.1.1');
      expect(entries.single.macAddress, 'aa:bb:cc:dd:ee:ff');
    });

    test('zero-pads octets that macOS prints without leading zeros', () {
      const raw = '? (10.0.0.5) at 0:1a:2b:3:4:5 on en0 ifscope [ethernet]';

      final entries = parseArpOutput(raw);

      expect(entries.single.macAddress, '00:1a:2b:03:04:05');
    });

    test('returns an empty list for blank output', () {
      expect(parseArpOutput(''), isEmpty);
    });

    test('returns an empty list when nothing matches', () {
      expect(parseArpOutput('arp: no matching entries found'), isEmpty);
    });
  });
}
