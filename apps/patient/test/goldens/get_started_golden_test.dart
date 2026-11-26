// Get started (GS1) in each state, at 360x640 and 390x844, text at 100% and 200% (GI-60). Reduced motion, so every
// frame is exact. Regenerate after an approved design change: flutter test --update-goldens test/goldens
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/shared/widgets/google_button.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/fonts.dart';
import '../support/get_started_driver.dart';

const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 2.0];

String _name(Size s, double scale) => '${s.width.toInt()}x${s.height.toInt()}_text${(scale * 100).toInt()}';

typedef _Setup = Future<void> Function(WidgetTester tester, Size size, double scale, GlobalKey key);

final Map<String, _Setup> _states = {
  // nothing typed yet: ten painted dots, Send code resting
  'empty': (tester, size, scale, key) => pumpGetStarted(tester, size: size, textScale: scale, key: key),
  // typing, keyboard open (a short phone folds into the compact layout)
  'typing': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key);
    await tester.enterText(phoneInput, '987654');
    await setKeyboard(tester, boardKeyboard(size));
  },
  // a good number: tick, happy a, Send code awake
  'ready': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key);
    await tester.enterText(phoneInput, '9876543210');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  },
  // GI-21: starts with 0–5
  'wrong': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key);
    await tester.enterText(phoneInput, '12345');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  },
  'sending': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key);
    await tester.enterText(phoneInput, '9876543210');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
  },
  'sent': (tester, size, scale, key) async {
    await pumpGetStarted(
      tester,
      size: size,
      textScale: scale,
      key: key,
      sender: FakeSender(next: const CodeSent()),
    );
    await tester.enterText(phoneInput, '9876543210');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
  },
  // GI-26
  'wait': (tester, size, scale, key) async {
    await pumpGetStarted(
      tester,
      size: size,
      textScale: scale,
      key: key,
      sender: FakeSender(next: const SendWait(Duration(seconds: 42))),
    );
    await tester.enterText(phoneInput, '9876543210');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
  },
  // GI-12
  'offline': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key, online: false);
    await tester.enterText(phoneInput, '9876543210');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  },
  // GI-37
  'google': (tester, size, scale, key) async {
    await pumpGetStarted(tester, size: size, textScale: scale, key: key);
    await tester.tap(find.byType(GoogleButton));
    await tester.pump();
  },
};

void main() {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: state, value: setUp) in _states.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('get started, $state ${_name(size, scale)}', (tester) async {
          final key = GlobalKey();
          await setUp(tester, size, scale, key);
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          await expectLater(find.byKey(key), matchesGoldenFile('get_started/${state}_${_name(size, scale)}.png'));
        });
      }
    }
  }
}
