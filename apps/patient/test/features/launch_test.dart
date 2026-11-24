import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apnedoctors/features/launch/launch_gate.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';
import 'package:apnedoctors/features/opening/opening_screen.dart';
import 'package:apnedoctors/features/welcome/welcome_host.dart';

import '../support/fonts.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadAppFonts);

  group('LaunchStore', () {
    test('EC-LAUNCH-04: a fresh device has not opened the app; marking is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsLaunchStore(await SharedPreferences.getInstance());
      expect(store.openedBefore, isFalse);
      await store.markOpened();
      final again = PrefsLaunchStore(await SharedPreferences.getInstance());
      expect(again.openedBefore, isTrue);
    });
  });

  Widget gate(LaunchKind kind, {bool reduced = false}) => phone(
    const LaunchGate(),
    reducedMotion: reduced,
    overrides: [launchKindProvider.overrideWithValue(kind), launchStoreProvider.overrideWithValue(MemoryLaunchStore())],
  );

  testWidgets('EC-LAUNCH-01: the first open plays the full opening', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(gate(LaunchKind.firstOpen));
    expect(find.byType(OpeningScreen), findsOneWidget);
  });

  testWidgets('EC-LAUNCH-04: opened before goes to Welcome, never the full opening again', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(gate(LaunchKind.returning));
    expect(find.byType(OpeningScreen), findsNothing);
    expect(find.byType(WelcomeHost), findsOneWidget);
  });

  testWidgets('EC-LAUNCH-07: reduced motion skips the opening and nothing keeps moving', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(gate(LaunchKind.firstOpen, reduced: true));
    expect(find.byType(OpeningScreen), findsNothing);
    expect(find.byType(WelcomeHost), findsOneWidget);
    await tester.pumpAndSettle(); // settles only if no ticker runs
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
