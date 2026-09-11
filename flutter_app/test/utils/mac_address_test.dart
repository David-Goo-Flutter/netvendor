import 'package:flutter_test/flutter_test.dart';
import 'package:netvendor/utils/mac_address.dart';

void main() {
  group('normalizeMacAddress', () {
    const cases = {
      'AA:BB:CC:DD:EE:FF': 'aa:bb:cc:dd:ee:ff',
      'aa-bb-cc-dd-ee-ff': 'aa:bb:cc:dd:ee:ff',
      '0:1a:2b:3:4:5': '00:1a:2b:03:04:05',
    };

    cases.forEach((input, expected) {
      test('normalizes $input', () {
        expect(normalizeMacAddress(input), expected);
      });
    });

    for (final invalid in ['not-a-mac', 'aa:bb:cc:dd:ee', '(incomplete)', 'aa:bb-cc:dd:ee:ff']) {
      test('rejects $invalid', () {
        expect(normalizeMacAddress(invalid), isNull);
      });
    }
  });

  group('isValidMacAddress', () {
    test('true for a valid MAC', () => expect(isValidMacAddress('aa:bb:cc:dd:ee:ff'), isTrue));
    test('false for garbage', () => expect(isValidMacAddress('nope'), isFalse));
  });
}
