import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/get_started/code_screen.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/get_started_a.dart';
import 'package:apnedoctors/features/get_started/get_started_screen.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';
import 'package:apnedoctors/shared/widgets/code_tiles.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/code_driver.dart';
import '../support/fonts.dart';
import '../support/get_started_driver.dart';
import '../support/harness.dart';

CodeLook look(WidgetTester tester) => tester.widget<CodeTiles>(find.byType(CodeTiles)).look;
GsMood mood(WidgetTester tester) => tester.widget<GetStartedA>(find.byType(GetStartedA)).mood;

void main() {
  setUpAll(loadAppFonts);

  group('arriving', () {
    testWidgets('says where the code went, and the tiles are ready', (tester) async {
      await pumpCodeScreen(tester);
      expect(findParagraph(CodeCopy.headline), findsOneWidget);
      expect(find.text(CodeCopy.sentTo), findsOneWidget);
      expect(find.bySemanticsLabel('Change number, plus 91 98765 43210'), findsOneWidget);
      expect(look(tester), CodeLook.typing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(mood(tester), GsMood.listening);
      expect(find.text(CodeCopy.resendIn(const Duration(seconds: 60))), findsOneWidget);
    });
  });

  group('checking', () {
    testWidgets('checks by itself when the sixth digit lands, once, and the a looks up', (tester) async {
      final v = FakeVerifier(hold: true);
      await pumpCodeScreen(tester, verifier: v);
      await tester.enterText(codeInput, '48291');
      expect(v.codes, isEmpty);
      await tester.enterText(codeInput, '482913');
      await tester.pump();
      expect(v.codes, ['482913']);
      expect(look(tester), CodeLook.checking);
      expect(findParagraph(CodeCopy.checking), findsOneWidget);
      expect(mood(tester), GsMood.thinking);
      v.pending!.complete(const Verified());
      await tester.pump();
    });

    testWidgets('verified: green tiles, the a celebrates, signed in, the waiting code is forgotten', (tester) async {
      final store = await pumpCodeScreen(tester);
      store.pendingCode = PendingCode(e164: testPhone.e164, sentAt: clock.now());
      await tester.enterText(codeInput, '482913');
      await tester.pump();
      expect(look(tester), CodeLook.verified);
      expect(findParagraph(CodeCopy.verified), findsOneWidget);
      expect(mood(tester), GsMood.celebrating);
      expect(store.pendingCode, isNull);
    });

    testWidgets('GI-25: a wrong code shakes, says how many tries are left, and clears', (tester) async {
      await pumpCodeScreen(tester);
      await tester.enterText(codeInput, '111111');
      await tester.pump();
      expect(look(tester), CodeLook.wrong);
      expect(findParagraph(CodeCopy.wrong(2)), findsOneWidget);
      expect(mood(tester), GsMood.worried);
      await tester.pump(const Duration(seconds: 1));
      expect(look(tester), CodeLook.typing);
      expect(tester.widget<EditableText>(codeInput).controller.text, '');
      await tester.enterText(codeInput, '222222');
      await tester.pump();
      expect(findParagraph(CodeCopy.wrong(1)), findsOneWidget);
    });

    testWidgets('GI-25: after three wrong codes, a new code is needed', (tester) async {
      final sender = FakeSender(next: const CodeSent());
      await pumpCodeScreen(tester, sender: sender);
      for (final c in ['111111', '222222', '333333']) {
        await tester.enterText(codeInput, c);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(look(tester), CodeLook.locked);
      expect(findParagraph(CodeCopy.outOfTries), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, CodeCopy.resend));
      await tester.pump();
      expect(sender.calls, hasLength(1));
      expect(look(tester), CodeLook.typing);
      expect(findParagraph(CodeCopy.newCode), findsOneWidget);
    });

    testWidgets('GI-27: an old code is called expired, with one tap for a new one', (tester) async {
      final sender = FakeSender(next: const CodeSent());
      await pumpCodeScreen(tester, sender: sender, sentAt: clock.now().subtract(const Duration(minutes: 3)));
      await tester.enterText(codeInput, '482913'.replaceAll('3', '4'));
      await tester.pump();
      expect(findParagraph(CodeCopy.expired), findsOneWidget);
      expect(look(tester), CodeLook.locked);
      await tester.tap(find.widgetWithText(PrimaryButton, CodeCopy.resend));
      await tester.pump();
      expect(sender.calls, hasLength(1));
      expect(look(tester), CodeLook.typing);
    });

    testWidgets('GI-26: too many tries shows the server\'s real wait', (tester) async {
      await pumpCodeScreen(tester, verifier: FakeVerifier(next: const VerifyWait(Duration(minutes: 12))));
      await tester.enterText(codeInput, '482913');
      await tester.pump();
      expect(findParagraph('Too many tries. Try again in 12 minutes.'), findsOneWidget);
      expect(look(tester), CodeLook.locked);
    });

    testWidgets('GI-67: no answer says so and lets you type again', (tester) async {
      await pumpCodeScreen(tester, verifier: FakeVerifier(next: const VerifyFailed(SendCopy.unreachable)));
      await tester.enterText(codeInput, '482913');
      await tester.pump();
      expect(findParagraph(SendCopy.unreachable), findsOneWidget);
      expect(look(tester), CodeLook.typing);
    });
  });

  group('a new code', () {
    testWidgets('waits for the server\'s minute, then sends again', (tester) async {
      final sender = FakeSender(next: const CodeSent());
      await pumpCodeScreen(tester, sender: sender);
      expect(find.text(CodeCopy.resend), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      await tester.pump(const Duration(milliseconds: 16)); // the card has grown into place
      await tester.tap(find.text(CodeCopy.again)); // the help card has it by now
      await tester.pump();
      await tester.pump();
      expect(sender.calls, hasLength(1));
    });

    testWidgets('GI-28: after 30 s, "Didn\'t get it?" offers to send again, check the number, or use Google', (
      tester,
    ) async {
      var changed = 0;
      await pumpCodeScreen(tester, onChange: () => changed++);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 16)); // the card has grown into place
      expect(find.text(CodeCopy.helpTitle), findsOneWidget);
      expect(find.text(CodeCopy.again), findsOneWidget);
      expect(find.textContaining('In 0:'), findsOneWidget); // not yet: the server's minute
      await tester.tap(find.text(CodeCopy.google));
      await tester.pump();
      expect(findParagraph(CodeCopy.googleNote), findsOneWidget);
      await tester.tap(find.text(CodeCopy.check));
      expect(changed, 1);
    });
  });

  group('the screen', () {
    testWidgets('GI-30: back goes to the number; GI-31: Change forgets this code', (tester) async {
      var back = 0, change = 0;
      final store = await pumpCodeScreen(tester, onBack: () => back++, onChange: () => change++);
      store.pendingCode = PendingCode(e164: testPhone.e164, sentAt: clock.now());
      await tester.tap(find.bySemanticsLabel('Back to your number'));
      expect(back, 1);
      await tester.tap(find.bySemanticsLabel('Change number, plus 91 98765 43210'));
      expect(change, 1);
      expect(store.pendingCode, isNull);
    });

    testWidgets('GI-63: a short phone with the keyboard open keeps the tiles and the line above it', (tester) async {
      const size = Size(360, 640);
      await pumpCodeScreen(tester, size: size);
      await tester.enterText(codeInput, '48');
      await setKeyboard(tester, 298);
      expect(findParagraph(CodeCopy.headlineCompact), findsOneWidget);
      expect(tester.getRect(find.byType(CodeTiles)).bottom, lessThanOrEqualTo(640 - 298));
    });

    testWidgets('GI-60: at 200% text on a small phone nothing clips', (tester) async {
      await pumpCodeScreen(tester, size: const Size(360, 640), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GI-61: the tiles are one field; the number and back are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCodeScreen(tester);
      expect(find.bySemanticsLabel('6-digit code'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to your number'), findsOneWidget);
      expect(find.bySemanticsLabel('Change number, plus 91 98765 43210'), findsOneWidget);
      handle.dispose();
    });
  });

  group('from the phone screen and back', () {
    GoRouter router({String initial = Routes.getStarted}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
        GoRoute(path: Routes.code, pageBuilder: codePage),
      ],
    );

    testWidgets('Send code opens the code screen with the number; Back keeps it (GI-30)', (tester) async {
      setPhone(tester, const Size(390, 844));
      final store = MemoryLaunchStore();
      await tester.pumpWidget(
        phone(
          ApneDoctorsApp(routerConfig: router()),
          overrides: [
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            phoneCodeSenderProvider.overrideWithValue(FakeSender(next: const CodeSent())),
            codeVerifierProvider.overrideWithValue(FakeVerifier()),
            launchStoreProvider.overrideWithValue(store),
          ],
        ),
      );
      await tester.pump();
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(store.pendingCode?.e164, '+919876543210'); // kept if the app is closed now (GI-29)
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      final arrival = tester.widget<CodeScreen>(find.byType(CodeScreen)).arrival;
      expect(arrival.phone.e164, '+919876543210');
      expect(arrival.numberFrom, isNotNull); // the number flies up from its field
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull); // mid-move
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.bySemanticsLabel('Back to your number'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(CodeScreen), findsNothing);
      expect(find.byType(GetStartedScreen), findsOneWidget);
      expect(tester.widget<EditableText>(phoneInput).controller.text, '98765 43210');
    });

    testWidgets('GI-29: a code sent minutes ago brings the app back to the code screen', (tester) async {
      setPhone(tester, const Size(390, 844));
      final store = MemoryLaunchStore()
        ..pendingCode = PendingCode(e164: '+919876543210', sentAt: clock.now().subtract(const Duration(minutes: 2)));
      final r = GoRouter(
        redirect: (context, state) => state.matchedLocation == '/' ? Routes.code : null,
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
          GoRoute(path: Routes.code, pageBuilder: codePage),
        ],
      );
      await tester.pumpWidget(
        phone(
          ApneDoctorsApp(routerConfig: r),
          overrides: [
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            launchStoreProvider.overrideWithValue(store),
            codeVerifierProvider.overrideWithValue(FakeVerifier()),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(CodeScreen), findsOneWidget);
      expect(tester.widget<CodeScreen>(find.byType(CodeScreen)).arrival.phone.e164, '+919876543210');
    });
  });

  group('Supabase\'s answers, in plain words', () {
    test('a wrong or expired code is rejected', () {
      expect(
        verifyResultFor(
          const AuthApiException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired'),
        ),
        isA<VerifyRejected>(),
      );
    });

    test('GI-26: too many tries carries the wait when the server gives one', () {
      final r = verifyResultFor(
        const AuthApiException(
          'For security purposes, you can only request this after 20 seconds.',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
      );
      expect((r as VerifyWait).wait, const Duration(seconds: 20));
    });

    test('GI-67: no answer at all', () {
      expect((verifyResultFor(AuthRetryableFetchException()) as VerifyFailed).message, SendCopy.unreachable);
    });

    test('the waits between codes grow: 1, 2, then 3 minutes', () {
      expect(CodeRules.resendAfter(1), const Duration(minutes: 1));
      expect(CodeRules.resendAfter(2), const Duration(minutes: 2));
      expect(CodeRules.resendAfter(5), const Duration(minutes: 3));
    });
  });
}
