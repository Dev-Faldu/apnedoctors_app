// The code screen (GS2) in each state, at 360x640 and 390x844, text at 100% and 200% (GI-60). Reduced motion, so
// every frame is exact. Regenerate after an approved design change: flutter test --update-goldens test/goldens
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/get_started/code_verifier.dart';

import '../support/code_driver.dart';
import '../support/fonts.dart';
import '../support/get_started_driver.dart';

const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 2.0];

String _name(Size s, double scale) => '${s.width.toInt()}x${s.height.toInt()}_text${(scale * 100).toInt()}';

/// The number pad plus the one-time-code bar above it.
double _keyboard(Size s) => s.height < 700 ? 298 : 335;

typedef _Setup = Future<void> Function(WidgetTester tester, Size size, double scale, GlobalKey key);

final Map<String, _Setup> _states = {
  // just arrived: the keyboard is up, the first tile waits with the caret
  'waiting': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key);
    await setKeyboard(tester, _keyboard(size));
  },
  'typing': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key);
    await tester.enterText(codeInput, '482');
    await setKeyboard(tester, _keyboard(size));
  },
  'checking': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key, verifier: FakeVerifier(hold: true));
    await tester.enterText(codeInput, '482913');
    await setKeyboard(tester, _keyboard(size));
  },
  // GI-25
  'wrong': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key);
    await tester.enterText(codeInput, '482931');
    await tester.pump();
  },
  'verified': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key);
    await tester.enterText(codeInput, '482913');
    await tester.pump();
  },
  // GI-27
  'expired': (tester, size, scale, key) async {
    await pumpCodeScreen(
      tester,
      size: size,
      textScale: scale,
      key: key,
      sentAt: clock.now().subtract(const Duration(minutes: 3)),
    );
    await tester.enterText(codeInput, '111111');
    await tester.pump();
  },
  // GI-26
  'wait': (tester, size, scale, key) async {
    await pumpCodeScreen(
      tester,
      size: size,
      textScale: scale,
      key: key,
      verifier: FakeVerifier(next: const VerifyWait(Duration(minutes: 12))),
    );
    await tester.enterText(codeInput, '482913');
    await tester.pump();
  },
  // GI-28
  'help': (tester, size, scale, key) async {
    await pumpCodeScreen(tester, size: size, textScale: scale, key: key);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 42));
  },
};

void main() {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: state, value: setUp) in _states.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('code screen, $state ${_name(size, scale)}', (tester) async {
          final key = GlobalKey();
          await setUp(tester, size, scale, key);
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await expectLater(find.byKey(key), matchesGoldenFile('code_screen/${state}_${_name(size, scale)}.png'));
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(seconds: 2));
        });
      }
    }
  }
}
