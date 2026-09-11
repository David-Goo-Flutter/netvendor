import 'package:flutter_test/flutter_test.dart';
import 'package:netvendor/utils/ip_address.dart';

void main() {
  group('isValidIPv4Address', () {
    for (final valid in ['192.168.1.1', '0.0.0.0', '255.255.255.255', '10.0.0.254']) {
      test('accepts $valid', () => expect(isValidIPv4Address(valid), isTrue));
    }

    for (final invalid in ['256.1.1.1', '192.168.1', '192.168.1.1.1', 'not-an-ip', '192.168.1.1/24', '']) {
      test('rejects $invalid', () => expect(isValidIPv4Address(invalid), isFalse));
    }
  });
}
