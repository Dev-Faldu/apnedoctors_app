// About you (GS3 · G7) in each state, at 360x640 and 390x844, text at 100% and 200% (GI-60). Reduced motion, so
// every frame is exact. Regenerate after an approved design change: flutter test --update-goldens test/goldens
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/about_you/about_you_parts.dart';
import 'package:apnedoctors/features/about_you/about_you_screen.dart';
import 'package:apnedoctors/features/about_you/basics.dart';

import '../support/about_driver.dart';
import '../support/fonts.dart';
import '../support/get_started_driver.dart';

const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 2.0];

String _name(Size s, double scale) => '${s.width.toInt()}x${s.height.toInt()}_text${(scale * 100).toInt()}';

/// The letters keyboard with its suggestion bar.
double _keyboard(Size s) => s.height < 700 ? 298 : 335;

int get _thisYear => istToday(clock.now()).year;

/// Taps [f] once it is scrolled into view (at large text it may start below Continue).
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

typedef _Setup = Future<void> Function(WidgetTester tester, Size size, double scale, GlobalKey key);

final Map<String, _Setup> _states = {
  // just arrived: the a says namaste
  'name': (tester, size, scale, key) async {
    await pumpAboutYou(tester, size: size, textScale: scale, key: key);
  },
  // typing with the keyboard open: the a and its bubble go up into the top bar (GI-63)
  'name_typing': (tester, size, scale, key) async {
    await pumpAboutYou(tester, size: size, textScale: scale, key: key);
    await tester.enterText(firstNameInput, 'Priya');
    await setKeyboard(tester, _keyboard(size));
  },
  'birth': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: _thisYear - 22),
    );
  },
  // GI-40
  'birth_this_year': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: BasicsDraft(step: 'birth', first: 'Priya', month: 1, year: _thisYear),
    );
  },
  'confirm': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: _thisYear - 22),
    );
    await _tap(tester, find.text(AboutCopy.next));
  },
  'age': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 52),
    );
  },
  // GI-46
  'age_under_18': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 18),
    );
    await _tap(tester, find.byWidgetPredicate((w) => w is PlusMinusMark && !w.plus));
  },
  'gender': (tester, size, scale, key) async {
    await pumpAboutYou(tester, size: size, textScale: scale, key: key);
    await tester.enterText(firstNameInput, 'Priya');
    await tester.pump();
    await _tap(tester, find.text(AboutCopy.next));
    await _tap(tester, find.text(AboutCopy.next));
    await _tap(tester, find.text(AboutCopy.yes));
    await _tap(tester, find.text(Gender.woman.label));
  },
  'done': (tester, size, scale, key) async {
    await pumpAboutYou(
      tester,
      size: size,
      textScale: scale,
      key: key,
      draft: BasicsDraft(step: 'birth', first: 'Priya', last: 'Shah', month: 3, year: _thisYear - 22),
    );
    await _tap(tester, find.text(AboutCopy.next));
    await _tap(tester, find.text(AboutCopy.yes));
    await _tap(tester, find.text(Gender.woman.label));
    await _tap(tester, find.text(AboutCopy.next));
  },
  // GI-41
  'too_young': (tester, size, scale, key) async {
    await pumpAboutYou(tester, size: size, textScale: scale, key: key, start: AboutStep.tooYoung);
  },
};

void main() {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: state, value: setUp) in _states.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('about you, $state ${_name(size, scale)}', (tester) async {
          final key = GlobalKey();
          await setUp(tester, size, scale, key);
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await expectLater(find.byKey(key), matchesGoldenFile('about_you/${state}_${_name(size, scale)}.png'));
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(seconds: 2));
        });
      }
    }
  }
}
