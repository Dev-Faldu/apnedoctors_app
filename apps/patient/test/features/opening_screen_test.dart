import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/css_paragraph.dart';
import 'package:apnedoctors/features/opening/opening_screen.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/features/welcome/welcome_host.dart';

import '../support/fonts.dart';
import '../support/harness.dart';

const frame = Duration(microseconds: 16667);

Future<void> run(WidgetTester tester, double seconds) async {
  final n = (seconds * 60).round();
  for (var i = 0; i < n; i++) {
    await tester.pump(frame);
  }
}

OpeningScreenState stateOf(WidgetTester tester) => tester.state<OpeningScreenState>(find.byType(OpeningScreen));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the opening settles into Welcome after the hand-off and says so once', (tester) async {
    setPhone(tester, const Size(390, 844));
    var settled = 0;
    await tester.pumpWidget(phone(OpeningScreen(onSettled: () => settled++)));
    await run(tester, 9.0);
    expect(settled, 0);
    await run(tester, 1.2);
    expect(settled, 1);
    await run(tester, 2);
    expect(settled, 1);
  });

  testWidgets('tap to skip fast-forwards smoothly to the settled Welcome (no jump)', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const OpeningScreen()));
    await run(tester, 1.0);
    await tester.tapAt(const Offset(195, 200));
    await tester.pump(frame);
    final s = stateOf(tester);
    expect(s.fastForwarding, isTrue);
    // every frame moves forward by a bounded step, so the motion stays continuous
    var last = s.time;
    var frames = 0;
    while (s.fastForwarding) {
      await tester.pump(frame);
      expect(s.time - last, lessThan(.3));
      last = s.time;
      frames++;
    }
    expect(frames, lessThanOrEqualTo(40), reason: 'about 0.6 s');
    expect(s.time, greaterThanOrEqualTo(OpeningScreenState.settled));
  });

  testWidgets('EC-LAUNCH-12: back from the background mid-opening, it finishes instantly', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const OpeningScreen()));
    await run(tester, 2.0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(frame);
    expect(stateOf(tester).time, greaterThanOrEqualTo(OpeningScreenState.settled));
  });

  testWidgets('Welcome buttons work once it has settled', (tester) async {
    setPhone(tester, const Size(390, 844));
    var started = 0, signIn = 0, pro = 0;
    await tester.pumpWidget(
      phone(OpeningScreen(onGetStarted: () => started++, onSignIn: () => signIn++, onForDoctors: () => pro++)),
    );
    await run(tester, 10.2);
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('I already have an account'));
    await tester.tap(find.text('For doctors'));
    expect((started, signIn, pro), (1, 1, 1));
  });

  testWidgets('the doctors chip never pops in while the a glides into the doorway', (tester) async {
    setPhone(tester, const Size(390, 844));
    Widget app(DoctorsOnline? d) => phone(OpeningScreen(doctorsOnline: d));
    await tester.pumpWidget(app(null));
    await run(tester, 6.2); // hand-off under way
    await tester.pumpWidget(app(boardDoctorsOnline));
    await run(tester, 1.0);
    expect(find.text('14 doctors online now'), findsNothing, reason: 'held until Welcome settles');
    await run(tester, 2.9); // Welcome settles at 9.9 s; this is 0.2 s after
    final mid = tester.getSize(find.byType(AnimatedSize)).height;
    expect(mid, inExclusiveRange(1, 56), reason: 'sliding in, not popping');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('14 doctors online now'), findsOneWidget);
    expect(tester.getSize(find.byType(AnimatedSize)).height, 56);
  });

  testWidgets('a count that arrives before the hand-off is there from the start', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const OpeningScreen()));
    await run(tester, 2);
    await tester.pumpWidget(phone(const OpeningScreen(doctorsOnline: boardDoctorsOnline)));
    await run(tester, 8.5);
    expect(find.text('14 doctors online now'), findsOneWidget);
  });

  testWidgets('if everyone goes offline mid hand-off, the chip leaves after Welcome settles', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const OpeningScreen(doctorsOnline: boardDoctorsOnline)));
    await run(tester, 6.5);
    await tester.pumpWidget(phone(const OpeningScreen()));
    await run(tester, 1.0);
    expect(find.text('14 doctors online now'), findsOneWidget, reason: 'held');
    await run(tester, 3.0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('14 doctors online now'), findsNothing);
  });

  testWidgets('no made-up numbers: the doctors chip only shows with real data', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true)));
    expect(find.textContaining('doctors online'), findsNothing);
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: DoctorsOnline(count: 0))));
    expect(find.textContaining('online'), findsNothing);
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: DoctorsOnline(count: 1))));
    expect(find.text('1 doctor online now'), findsOneWidget);
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: boardDoctorsOnline)));
    expect(find.text('14 doctors online now'), findsOneWidget);
  });

  testWidgets('EC-A11Y-02: screen readers hear the brand, the doorway, the headline and every button', (tester) async {
    setPhone(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: boardDoctorsOnline)));
    expect(find.bySemanticsLabel('ApneDoctors'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('painted Indian doorway')), findsOneWidget);
    expect(find.bySemanticsLabel('14 doctors online now'), findsOneWidget);
    for (final b in ['Get started', 'I already have an account', 'For doctors']) {
      expect(find.bySemanticsLabel(b), findsOneWidget, reason: b);
    }
    expect(
      tester.getSemantics(find.text('doctors who\nfeel like\nfamily.')),
      matchesSemantics(label: 'doctors who\nfeel like\nfamily.', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('EC-A11Y-04: every touch target is at least 48 x 48', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true)));
    for (final label in ['Get started', 'I already have an account', 'For doctors']) {
      final box = tester.renderObject<RenderBox>(
        find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first,
      );
      expect(box.size.height, greaterThanOrEqualTo(48), reason: label);
      expect(box.size.width, greaterThanOrEqualTo(48), reason: label);
    }
  });

  for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
    testWidgets('EC-A11Y-01: 200% text fits without overflow at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      setPhone(tester, size);
      await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: boardDoctorsOnline), textScale: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Get started'), findsOneWidget);
    });
  }

  testWidgets('Welcome at 390x844 lands on the board layout (N01Welcome measured in Chrome)', (tester) async {
    setPhone(tester, const Size(390, 844));
    await tester.pumpWidget(phone(const WelcomeHost(reduced: true, doctorsOnline: boardDoctorsOnline)));
    Rect r(Finder f) => tester.getRect(f);
    expect(r(find.text('doctors who\nfeel like\nfamily.')).top, closeTo(438.72, .02));
    final lede = r(find.byType(CssParagraph));
    expect(lede.top, closeTo(591.72, .02));
    expect(lede.height, closeTo(49.28, .02));
    expect(
      r(find.text('14 doctors online now')).topLeft,
      offsetMoreOrLessEquals(const Offset(135, 668.5), epsilon: .05),
    );
    expect(r(find.text('Get started')).top, closeTo(733.5, .05));
    expect(r(find.text('For doctors')).topLeft, offsetMoreOrLessEquals(const Offset(266.25, 29.5), epsilon: .05));
  });
}
