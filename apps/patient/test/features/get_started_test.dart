import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/get_started/get_started_a.dart';
import 'package:apnedoctors/features/get_started/get_started_screen.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/features/welcome/doorway_hand_off.dart';
import 'package:apnedoctors/features/welcome/welcome_host.dart';
import 'package:apnedoctors/shared/indian_phone.dart';
import 'package:apnedoctors/shared/widgets/google_button.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/fonts.dart';
import '../support/get_started_driver.dart';
import '../support/harness.dart';

PrimaryButton sendButton(WidgetTester tester) => tester.widget<PrimaryButton>(find.byType(PrimaryButton));
GsMood mood(WidgetTester tester) => tester.widget<GetStartedA>(find.byType(GetStartedA)).mood;

void main() {
  setUpAll(loadAppFonts);

  group('the number', () {
    testWidgets('empty: Send code rests, the a listens', (tester) async {
      await pumpGetStarted(tester);
      expect(find.text('let’s get\nyou in.'), findsNothing); // drawn on CSS line boxes
      expect(findParagraph(GsCopy.headline), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);
      expect(mood(tester), GsMood.listening);
    });

    testWidgets('GI-20, GI-22: a pasted +91 number wakes Send code and makes the a happy', (tester) async {
      await pumpGetStarted(tester);
      await tester.enterText(phoneInput, '+91 98765-43210');
      await tester.pump();
      expect(sendButton(tester).onPressed, isNotNull);
      expect(mood(tester), GsMood.happy);
    });

    testWidgets('GI-21: a first digit of 0–5 worries the a and says what a mobile looks like', (tester) async {
      await pumpGetStarted(tester);
      await tester.enterText(phoneInput, '4');
      await tester.pump();
      expect(findParagraph(phoneStartHint), findsOneWidget);
      expect(mood(tester), GsMood.worried);
      expect(sendButton(tester).onPressed, isNull);
    });

    testWidgets('GI-23: another country\'s number is refused, nothing is sent', (tester) async {
      final sender = FakeSender();
      await pumpGetStarted(tester, sender: sender);
      await tester.enterText(phoneInput, '+44 7700 900123');
      await tester.pump();
      expect(findParagraph('For now we can only send codes to Indian mobile numbers.'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);
      expect(sender.calls, isEmpty);
    });
  });

  group('sending', () {
    Future<FakeSender> ready(WidgetTester tester, {SendResult? next}) async {
      final sender = FakeSender(next: next);
      await pumpGetStarted(tester, sender: sender);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump();
      return sender;
    }

    testWidgets('GI-24: a double tap sends one request; the field locks and the a looks up', (tester) async {
      final sender = await ready(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(sender.calls.map((p) => p.e164), ['+919876543210']);
      expect(sendButton(tester).loading, isTrue);
      expect(find.text(GsCopy.sending), findsOneWidget);
      expect(mood(tester), GsMood.thinking);
      sender.pending!.complete(const CodeSent());
      await tester.pump();
    });

    testWidgets('code sent: says where, and offers to change the number', (tester) async {
      PhoneOk? sentTo;
      final sender = FakeSender(next: const CodeSent());
      await pumpGetStarted(tester, sender: sender, onCodeSent: (p) => sentTo = p);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(sentTo?.e164, '+919876543210');
      expect(findParagraph('Code sent to +91 98765 43210.'), findsOneWidget);
      expect(sendButton(tester).tone, ButtonTone.ink);
      await tester.tap(find.text(GsCopy.sentButton));
      await tester.pump();
      expect(tester.widget<EditableText>(phoneInput).controller.text, '');
    });

    testWidgets('GI-26: the server\'s limit shows as a real countdown, then Send code comes back', (tester) async {
      await ready(tester, next: const SendWait(Duration(seconds: 3)));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(findParagraph('Too many tries. Try again in 3 seconds.'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(findParagraph('Too many tries. Try again in 2 seconds.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('GI-66: after 10 s a slow send says so; it never spins forever', (tester) async {
      final sender = await ready(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump(const Duration(seconds: 11));
      expect(findParagraph(GsCopy.slow), findsOneWidget);
      sender.pending!.complete(const SendFailed(SendCopy.unreachable));
      await tester.pump();
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('GI-67: a failed send says what to do, gives the button back, and worries the a', (tester) async {
      await ready(tester, next: const SendFailed(SendCopy.unreachable));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(findParagraph(SendCopy.unreachable), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);
      expect(mood(tester), GsMood.worried);
      await tester.enterText(phoneInput, '98765 4321'); // editing clears the old problem
      await tester.pump();
      expect(findParagraph(SendCopy.unreachable), findsNothing);
    });
  });

  group('the screen', () {
    testWidgets('GI-12: offline, an ink pill slides in and both buttons rest', (tester) async {
      await pumpGetStarted(tester, online: false);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(GsCopy.offline), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);
      expect(tester.widget<GoogleButton>(find.byType(GoogleButton)).onPressed, isNull);
      expect(mood(tester), GsMood.worried);
    });

    testWidgets('GI-37: Google isn\'t set up yet, so it points to the phone number', (tester) async {
      await pumpGetStarted(tester);
      await tester.tap(find.byType(GoogleButton));
      await tester.pump();
      expect(findParagraph(GsCopy.google), findsOneWidget);
    });

    testWidgets('GI-63: a short phone with the keyboard open keeps Send code above it', (tester) async {
      const size = Size(360, 640);
      await pumpGetStarted(tester, size: size);
      await tester.enterText(phoneInput, '98765');
      await setKeyboard(tester, boardKeyboard(size));
      await tester.pump(const Duration(milliseconds: 400));
      expect(findParagraph(GsCopy.headlineCompact), findsOneWidget);
      expect(tester.getRect(find.byType(PrimaryButton)).bottom, lessThanOrEqualTo(640 - boardKeyboard(size)));
    });

    testWidgets('GI-63: a tall phone keeps the full layout with the keyboard open', (tester) async {
      await pumpGetStarted(tester);
      await tester.enterText(phoneInput, '98765');
      await setKeyboard(tester, boardKeyboard(const Size(390, 844)));
      expect(findParagraph(GsCopy.lede), findsOneWidget);
      expect(tester.getRect(find.byType(PrimaryButton)).bottom, lessThanOrEqualTo(844 - 291));
    });

    testWidgets('GI-64: back goes to Welcome', (tester) async {
      var back = 0;
      await pumpGetStarted(tester, onBack: () => back++);
      await tester.tap(find.bySemanticsLabel('Back to Welcome'));
      expect(back, 1);
    });

    testWidgets('GI-60: at 200% text on a small phone nothing clips; the page scrolls', (tester) async {
      await pumpGetStarted(tester, size: const Size(360, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pump();
      expect(find.textContaining('Sign in', findRichText: true), findsOneWidget);
    });

    testWidgets('GI-61: every control is labelled; the a is decorative', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGetStarted(tester);
      expect(find.bySemanticsLabel('Back to Welcome'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mobile number, plus 91')), findsOneWidget);
      expect(find.bySemanticsLabel('Send code'), findsOneWidget);
      expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
      expect(find.bySemanticsLabel('Already have an account? Sign in'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('GI-62: reduced motion still works, without the entrance', (tester) async {
      await pumpGetStarted(tester, entrance: true);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pumpAndSettle();
      expect(sendButton(tester).onPressed, isNotNull);
    });
  });

  group('the walk through the doorway', () {
    testWidgets('Get started carries the a from Welcome\'s doorway; Back brings it home', (tester) async {
      setPhone(tester, const Size(390, 844));
      AFlightStart? carried;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => WelcomeHost(
              doctorsOnline: boardDoctorsOnline,
              onGetStarted: () {
                carried = DoorwayHandOff.take();
                context.push(Routes.getStarted, extra: carried);
              },
            ),
          ),
          GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
        ],
      );
      await tester.pumpWidget(
        phone(
          ApneDoctorsApp(routerConfig: router),
          overrides: [
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            phoneCodeSenderProvider.overrideWithValue(FakeSender()),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('Get started'));
      await tester.pump();
      await tester.pump();
      expect(carried, isNotNull);
      expect(carried!.bowl.dy, greaterThan(200)); // from the doorway, below the top bar
      expect(tester.widget<GetStartedScreen>(find.byType(GetStartedScreen)).flightFrom, same(carried));
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull); // mid-walk
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(GetStartedScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back to Welcome'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull); // mid-way home
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GetStartedScreen), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
    });
  });

  group('Supabase\'s answers, in plain words', () {
    test('GI-26: a rate limit with a wait becomes that wait', () {
      final r = sendResultFor(
        const AuthApiException(
          'For security purposes, you can only request this after 37 seconds.',
          statusCode: '429',
          code: 'over_sms_send_rate_limit',
        ),
      );
      expect((r as SendWait).wait, const Duration(seconds: 37));
      expect(SendCopy.tooMany(r.wait!), 'Too many tries. Try again in 37 seconds.');
    });

    test('GI-26: a limit without a wait still never shows a raw error', () {
      final r = sendResultFor(const AuthApiException('SMS rate limit exceeded', statusCode: '429'));
      expect((r as SendWait).wait, isNull);
      expect(SendCopy.tooMany(const Duration(minutes: 11, seconds: 1)), 'Too many tries. Try again in 12 minutes.');
      expect(SendCopy.tooMany(const Duration(seconds: 1)), 'Too many tries. Try again in 1 second.');
    });

    test('an SMS provider problem asks to try again later', () {
      final r = sendResultFor(
        const AuthApiException(
          'Error sending confirmation OTP to provider',
          statusCode: '500',
          code: 'sms_send_failed',
        ),
      );
      expect((r as SendFailed).message, SendCopy.smsFailed);
    });

    test('a number the server refuses is called out as the number', () {
      final r = sendResultFor(
        const AuthApiException('Invalid phone number format', statusCode: '400', code: 'validation_failed'),
      );
      expect((r as SendFailed).wrongNumber, isTrue);
    });

    test('GI-67: no answer at all is "we can\'t reach ApneDoctors"', () {
      expect((sendResultFor(AuthRetryableFetchException()) as SendFailed).message, SendCopy.unreachable);
      expect(
        (sendResultFor(const AuthApiException('upstream', statusCode: '503')) as SendFailed).message,
        SendCopy.unreachable,
      );
    });
  });
}
