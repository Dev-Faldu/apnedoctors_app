import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/shared/indian_phone.dart';

void main() {
  group('GI-20 / GI-22: every way people write an Indian mobile becomes +91XXXXXXXXXX', () {
    for (final input in [
      '9876543210',
      '98765 43210',
      '98765-43210',
      '098765 43210',
      '+91 98765 43210',
      '+91-98765-43210',
      '91 98765 43210',
      '919876543210',
      '(+91) 98765.43210',
      '0091 98765 43210',
      '  9876543210  ',
    ]) {
      test(input, () {
        final p = parseIndianPhone(input);
        expect(p, isA<PhoneOk>());
        expect((p as PhoneOk).e164, '+919876543210');
        expect(p.display, '98765 43210');
        expect(p.masked, '+91 98•••••210');
      });
    }
  });

  group('GI-21: only ten digits starting 6 to 9', () {
    for (final input in ['5876543210', '987654321', '98765432101', '0123456789', 'call me', '98765abc10']) {
      test(input, () => expect((parseIndianPhone(input) as PhoneBad).problem, PhoneProblem.notAMobile));
    }
  });

  group('GI-23: international and premium-rate numbers are blocked', () {
    test('+1 (US)', () => expect((parseIndianPhone('+1 415 555 0100') as PhoneBad).problem, PhoneProblem.notIndian));
    test('+44 (UK)', () => expect((parseIndianPhone('+44 7700 900123') as PhoneBad).problem, PhoneProblem.notIndian));
    test(
      '1900 premium rate',
      () => expect((parseIndianPhone('1900 123 4567') as PhoneBad).problem, PhoneProblem.notAMobile),
    );
    test(
      '140 telemarketing',
      () => expect((parseIndianPhone('140 123 4567') as PhoneBad).problem, PhoneProblem.notAMobile),
    );
  });

  test('nothing typed asks for the number', () {
    expect((parseIndianPhone('  ') as PhoneBad).problem, PhoneProblem.empty);
    expect(phoneProblemText(PhoneProblem.notAMobile), 'That doesn’t look like an Indian mobile number.');
  });
}
