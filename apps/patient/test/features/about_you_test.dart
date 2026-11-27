import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/backend.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/about_you/about_you_parts.dart';
import 'package:apnedoctors/features/about_you/about_you_screen.dart';
import 'package:apnedoctors/features/about_you/basics.dart';
import 'package:apnedoctors/features/about_you/birth_wheel.dart';
import 'package:apnedoctors/features/get_started/code_screen.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/get_started_a.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/launch/launch_gate.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/about_driver.dart';
import '../support/code_driver.dart';
import '../support/fonts.dart';
import '../support/get_started_driver.dart';
import '../support/harness.dart';

SpeechBubble bubble(WidgetTester tester) => tester.widget<SpeechBubble>(find.byType(SpeechBubble));
String said(WidgetTester tester) {
  final b = bubble(tester);
  return '${b.prefix}${b.highlight}${b.suffix}';
}

GsMood mood(WidgetTester tester) => tester.widget<GetStartedA>(find.byType(GetStartedA)).mood;
bool continueOn(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, AboutCopy.next)).onPressed != null;

DateTime get today => istToday(clock.now());

Future<void> typeName(WidgetTester tester, String first, [String last = '']) async {
  await tester.enterText(firstNameInput, first);
  if (last.isNotEmpty) await tester.enterText(lastNameInput, last);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadAppFonts);

  group('your name', () {
    testWidgets('the a greets you, then says your name back as you type it', (tester) async {
      await pumpAboutYou(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(findParagraph(AboutCopy.nameHeadline), findsOneWidget);
      expect(said(tester), AboutCopy.hello);
      expect(continueOn(tester), isFalse);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      await typeName(tester, 'priya');
      expect(said(tester), 'namaste, Priya!');
      expect(bubble(tester).highlight, 'Priya'); // the name in vermilion
      expect(mood(tester), GsMood.happy); // a hop for your name
      await tester.pump(const Duration(seconds: 1));
      expect(mood(tester), GsMood.listening);
      expect(continueOn(tester), isTrue);
    });

    testWidgets('a name has letters only: numbers and symbols are caught', (tester) async {
      await pumpAboutYou(tester);
      await typeName(tester, 'Priya2');
      expect(find.text(AboutCopy.nameBad), findsOneWidget);
      expect(said(tester), AboutCopy.hello);
      expect(mood(tester), GsMood.worried);
      expect(continueOn(tester), isFalse);
      await typeName(tester, 'Priya', 'Sh@h');
      expect(find.text(AboutCopy.nameBad), findsOneWidget);
      expect(continueOn(tester), isFalse);
      await typeName(tester, 'Priya', 'D’Souza-Rao');
      expect(find.text(AboutCopy.nameBad), findsNothing);
      expect(continueOn(tester), isTrue);
    });

    testWidgets('the last name is optional', (tester) async {
      await pumpAboutYou(tester);
      await typeName(tester, 'Priya');
      await tapContinue(tester);
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
    });

    testWidgets('GI-61: both fields are labelled', (tester) async {
      await pumpAboutYou(tester);
      expect(find.bySemanticsLabel(RegExp('^${AboutCopy.first}')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^${AboutCopy.last}, ${AboutCopy.optional}')), findsOneWidget);
    });

    testWidgets('GI-63: with the keyboard open on a small phone, Continue stays above it', (tester) async {
      await pumpAboutYou(tester, size: const Size(360, 640));
      await typeName(tester, 'Priya');
      await tester.showKeyboard(lastNameInput);
      await setKeyboard(tester, 298);
      await tester.pump(const Duration(milliseconds: 500));
      final button = tester.getRect(find.widgetWithText(PrimaryButton, AboutCopy.next));
      expect(button.bottom, lessThanOrEqualTo(640 - 298));
      final field = tester.getRect(lastNameInput);
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThan(button.top));
      expect(tester.takeException(), isNull);
    });
  });

  group('when you were born', () {
    testWidgets('the wheel says how old that makes you', (tester) async {
      await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: today.year - 30),
      );
      final years = ageFrom(BirthMonth(today.year - 30, 3), today);
      expect(find.bySemanticsLabel(AboutCopy.makesYou(years)), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      expect(continueOn(tester), isTrue);
    });

    testWidgets('GI-61: the wheels are two adjustable controls', (tester) async {
      await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: today.year - 30),
      );
      final month = tester.getSemantics(find.bySemanticsLabel('Birth month'));
      expect(month.value, 'March');
      expect(month.increasedValue, 'April');
      final year = tester.getSemantics(find.bySemanticsLabel('Birth year'));
      expect(year.value, '${today.year - 30}');
    });

    testWidgets('turning the wheel changes the date', (tester) async {
      await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: today.year - 30),
      );
      final wheel = find.descendant(of: find.byType(BirthWheel), matching: find.byType(ListWheelScrollView));
      await tester.drag(wheel.last, const Offset(0, -88)); // two years later
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel('Birth year')).value, '${today.year - 28}');
    });

    testWidgets('GI-40: this year, or a month still to come, is turned down kindly', (tester) async {
      await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Priya', month: 1, year: today.year),
      );
      expect(find.text(AboutCopy.thisYear), findsOneWidget);
      expect(continueOn(tester), isFalse);
    });

    testWidgets('confirm before saving: "born in March 1996?", and Change it goes back', (tester) async {
      await pumpAboutYou(
        tester,
        draft: const BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: 1996),
      );
      await tapContinue(tester);
      expect(findParagraph(AboutCopy.confirmBirth(3, 1996)), findsOneWidget);
      expect(find.text(AboutCopy.confirmWhy), findsOneWidget);
      await tapText(tester, AboutCopy.change);
      expect(findParagraph(AboutCopy.confirmBirth(3, 1996)), findsNothing);
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
    });

    testWidgets('GI-64: back keeps your name', (tester) async {
      await pumpAboutYou(tester);
      await typeName(tester, 'Priya', 'Shah');
      await tapContinue(tester);
      await tester.tap(find.bySemanticsLabel('Back to your name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.widget<EditableText>(firstNameInput).controller.text, 'Priya');
      expect(tester.widget<EditableText>(lastNameInput).controller.text, 'Shah');
    });
  });

  group('only know your age (adults)', () {
    testWidgets('an age on its own is shown as an estimate', (tester) async {
      await pumpAboutYou(
        tester,
        draft: const BasicsDraft(step: 'birth', first: 'Ramesh', month: 3, year: 1990),
      );
      await tapText(tester, AboutCopy.onlyAge);
      expect(findParagraph(AboutCopy.ageHeadline), findsOneWidget);
      expect(find.textContaining(AboutCopy.estimate(30)), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Your age'));
      final age = tester.getSemantics(find.bySemanticsLabel('Your age'));
      expect(age.value, 'about 30 years');
    });

    testWidgets('GI-46: below 18 it explains why we need the month and year, and goes back to them', (tester) async {
      await pumpAboutYou(
        tester,
        draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 18),
      );
      final minus = find.byWidgetPredicate((w) => w is PlusMinusMark && !w.plus);
      await tester.tap(minus);
      await tester.pump();
      expect(find.text(AboutCopy.under18), findsOneWidget);
      expect(mood(tester), GsMood.worried);
      expect(find.bySemanticsLabel('Your age'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Your age')).value, 'about 18 years');
      await tapText(tester, AboutCopy.exact);
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
    });

    testWidgets('saved as an age, never a made-up birth month; the card says "about 52"', (tester) async {
      final r = await pumpAboutYou(
        tester,
        draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 52),
      );
      await tapContinue(tester);
      expect(findParagraph(AboutCopy.confirmAge(52)), findsOneWidget);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.man.label);
      await tapContinue(tester);
      final params = r.saver.saved.single.toParams();
      expect([params['age'], params['birth_year'], params['birth_month']], [52, null, null]);
      expect(find.text('about 52'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('everything is sent once, tidy; then "nice to meet you" and the card', (tester) async {
      final r = await pumpAboutYou(tester);
      await typeName(tester, 'priya', 'shah');
      await tapContinue(tester);
      await tapContinue(tester); // the default date, then the sheet
      await tapText(tester, AboutCopy.yes);
      expect(findParagraph(AboutCopy.genderHeadline), findsOneWidget);
      expect(continueOn(tester), isFalse);
      await tapText(tester, Gender.woman.label);
      expect(tester.getSemantics(find.bySemanticsLabel(Gender.woman.label)), isSemantics(isChecked: true));
      expect(continueOn(tester), isTrue);
      await tapContinue(tester);
      final params = r.saver.saved.single.toParams();
      expect(params['first_name'], 'Priya');
      expect(params['last_name'], 'Shah');
      expect(params['gender'], 'woman');
      expect([params['birth_month'], params['birth_year']], [3, today.year - 22]);
      expect(said(tester), '${AboutCopy.nice}Priya!');
      expect(find.text('Priya Shah'), findsOneWidget);
      expect(find.text(AboutCopy.nextAdult), findsOneWidget);
      expect(mood(tester), GsMood.celebrating);
      expect(r.store.basicsDraft, isNull); // saved: nothing left on the phone
      await tapContinue(tester);
      expect(r.done.single.nextStep, 'data_consent');
    });

    testWidgets('a teen hears that a parent says yes next', (tester) async {
      final y = today.year - 15;
      await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Aarav', month: 1, year: y),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.man.label);
      await tapContinue(tester);
      expect(find.text(AboutCopy.nextTeen(ageFrom(BirthMonth(y, 1), today))), findsOneWidget);
    });

    testWidgets('GI-40: over 100 needs the second yes, and it is sent', (tester) async {
      final r = await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Kamla', month: 1, year: today.year - 105),
      );
      await tapContinue(tester);
      expect(find.textContaining(AboutCopy.over100(ageFrom(BirthMonth(today.year - 105, 1), today))), findsOneWidget);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.woman.label);
      await tapContinue(tester);
      expect(r.saver.saved.single.confirmOver100, isTrue);
    });

    testWidgets('GI-67: the server can’t be reached: say so, and Continue tries again', (tester) async {
      final saver = FakeSaver(next: const SaveFailed(SendCopy.unreachable));
      await pumpAboutYou(
        tester,
        saver: saver,
        draft: const BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: 1996),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.woman.label);
      await tapContinue(tester);
      expect(find.text(SendCopy.unreachable), findsOneWidget);
      expect(findParagraph(AboutCopy.genderHeadline), findsOneWidget);
      saver.next = null;
      await tapContinue(tester);
      expect(saver.saved, hasLength(2));
      expect(said(tester), '${AboutCopy.nice}Priya!');
    });

    testWidgets('GI-66: a slow save says so after 10 s, and never runs twice', (tester) async {
      final saver = FakeSaver(hold: true);
      await pumpAboutYou(
        tester,
        saver: saver,
        draft: const BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: 1996),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.woman.label);
      await tester.tap(find.text(AboutCopy.next));
      await tester.pump();
      expect(find.bySemanticsLabel(AboutCopy.saving), findsOneWidget);
      expect(mood(tester), GsMood.thinking);
      await tester.tap(find.bySemanticsLabel(AboutCopy.saving));
      await tester.pump(const Duration(seconds: 11));
      expect(find.text(AboutCopy.slow), findsOneWidget);
      expect(saver.saved, hasLength(1));
      saver.pending!.complete(const Saved(nextStep: 'data_consent', teen: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(AboutCopy.slow), findsNothing);
    });

    testWidgets('GI-42: a birth date saved before can’t change here', (tester) async {
      final saver = FakeSaver(next: const SaveRefused(Refusal.birthLocked));
      await pumpAboutYou(
        tester,
        saver: saver,
        draft: const BasicsDraft(step: 'birth', first: 'Priya', month: 3, year: 1996),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.woman.label);
      await tapContinue(tester);
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
      expect(find.text(AboutCopy.locked), findsOneWidget);
    });

    testWidgets('GI-46: the server turning down an estimate under 18 goes back to month and year', (tester) async {
      final saver = FakeSaver(next: const SaveRefused(Refusal.exactBirthNeeded));
      await pumpAboutYou(
        tester,
        saver: saver,
        draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 30),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tapText(tester, Gender.man.label);
      await tapContinue(tester);
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
      expect(find.text(AboutCopy.under18), findsOneWidget);
    });
  });

  group('under 13 (GI-41)', () {
    testWidgets('only the birth date is checked; See you at 13 with Childline; this phone waits 7 days', (
      tester,
    ) async {
      final r = await pumpAboutYou(
        tester,
        draft: BasicsDraft(step: 'birth', first: 'Chintu', month: 1, year: today.year - 9),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tester.pump(const Duration(milliseconds: 700));
      final sent = r.saver.saved.single;
      expect(sent.firstName, isNull);
      expect(sent.gender, isNull);
      expect(findParagraph(AboutCopy.seeYouHeadline), findsOneWidget);
      expect(find.text(AboutCopy.seeYouBody), findsOneWidget);
      // never a hint of which year would pass
      expect(find.textContaining(RegExp(r'(19|20)\d\d')), findsNothing);
      expect(r.store.under13Until!.difference(clock.now()).inDays, 6); // 7 days, less a moment
      expect(r.store.basicsDraft, isNull);
      expect(r.saver.signOuts, 1);
      expect(find.text(AboutCopy.next).hitTestable(), findsNothing); // nothing to continue to
      await tester.tap(find.bySemanticsLabel('Call Childline, 1098. Free, any time.'));
      expect(r.calls, ['1098']);
    });

    testWidgets('no network: this phone stops here all the same', (tester) async {
      final saver = FakeSaver(next: const SaveFailed(SendCopy.unreachable));
      final r = await pumpAboutYou(
        tester,
        saver: saver,
        draft: BasicsDraft(step: 'birth', first: 'C', month: 1, year: today.year - 9),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tester.pump(const Duration(milliseconds: 700));
      expect(findParagraph(AboutCopy.seeYouHeadline), findsOneWidget);
      expect(r.store.under13Until, isNotNull);
    });

    testWidgets('GI-54: the server counts 13 or more (this phone’s clock is off): carry on', (tester) async {
      final saver = FakeSaver(next: const SaveRefused(Refusal.nameNeeded));
      await pumpAboutYou(
        tester,
        saver: saver,
        draft: BasicsDraft(step: 'birth', first: 'C', month: 1, year: today.year - 9),
      );
      await tapContinue(tester);
      await tapText(tester, AboutCopy.yes);
      await tester.pump(const Duration(milliseconds: 700));
      expect(findParagraph(AboutCopy.genderHeadline), findsOneWidget);
    });

    testWidgets('GI-16: at launch, the lock shows See you at 13 until it has passed', (tester) async {
      setPhone(tester, const Size(390, 844));
      final store = MemoryLaunchStore(openedBefore: true)..under13Until = clock.now().add(const Duration(days: 3));
      await tester.pumpWidget(
        phone(
          const LaunchGate(),
          reducedMotion: true,
          overrides: [
            launchKindProvider.overrideWithValue(LaunchKind.returning),
            launchStoreProvider.overrideWithValue(store),
            doctorsOnlineProvider.overrideWith((ref) => Stream.value(null)),
          ],
        ),
      );
      await tester.pump();
      expect(findParagraph(AboutCopy.seeYouHeadline), findsOneWidget);
    });
  });

  group('closing the app (GI-05)', () {
    testWidgets('what you type is kept on the phone, and comes back', (tester) async {
      final r = await pumpAboutYou(tester);
      await typeName(tester, 'Priya', 'Shah');
      await tapContinue(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final draft = BasicsDraft.fromJson(r.store.basicsDraft)!;
      expect([draft.step, draft.first, draft.last], ['birth', 'Priya', 'Shah']);
      await pumpAboutYou(tester, draft: draft, key: UniqueKey());
      expect(findParagraph(AboutCopy.birthHeadline), findsOneWidget);
    });

    testWidgets('signed in with About you unsaved, the app opens there; a code waiting wins; the lock wins over both', (
      tester,
    ) async {
      setPhone(tester, const Size(390, 844));
      Future<void> launch(MemoryLaunchStore store) async {
        resetLaunchRestore();
        final r = GoRouter(
          redirect: restoreOnLaunch,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const SizedBox(key: ValueKey('home')),
            ),
            GoRoute(path: Routes.code, pageBuilder: codePage),
            GoRoute(path: Routes.aboutYou, pageBuilder: aboutYouPage),
            GoRoute(path: Routes.getStarted, builder: (context, state) => const SizedBox()),
          ],
        );
        await tester.pumpWidget(
          KeyedSubtree(
            key: UniqueKey(),
            child: phone(
              ApneDoctorsApp(routerConfig: r),
              reducedMotion: true,
              overrides: [
                signedInProvider.overrideWithValue(true),
                launchStoreProvider.overrideWithValue(store),
                basicsSaverProvider.overrideWithValue(FakeSaver()),
                codeVerifierProvider.overrideWithValue(FakeVerifier()),
                onlineProvider.overrideWith((ref) => Stream.value(true)),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
      }

      await launch(MemoryLaunchStore()..basicsDraft = const BasicsDraft(first: 'Priya').toJson());
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(tester.widget<EditableText>(firstNameInput).controller.text, 'Priya');

      await launch(
        MemoryLaunchStore()
          ..basicsDraft = const BasicsDraft().toJson()
          ..pendingCode = PendingCode(e164: '+919876543210', sentAt: clock.now()),
      );
      expect(find.byType(CodeScreen), findsOneWidget);

      await launch(
        MemoryLaunchStore()
          ..basicsDraft = const BasicsDraft().toJson()
          ..under13Until = clock.now().add(const Duration(days: 1)),
      );
      expect(find.byKey(const ValueKey('home')), findsOneWidget);
    });
  });

  group('from the code screen', () {
    testWidgets('verified: the celebration plays, then About you takes over; no way back to the code', (tester) async {
      setPhone(tester, const Size(390, 844));
      final store = MemoryLaunchStore();
      final r = GoRouter(
        initialLocation: Routes.code,
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(path: Routes.getStarted, builder: (context, state) => const SizedBox()),
          GoRoute(path: Routes.code, pageBuilder: codePage),
          GoRoute(path: Routes.aboutYou, pageBuilder: aboutYouPage),
        ],
      );
      store.pendingCode = PendingCode(e164: '+919876543210', sentAt: clock.now());
      await tester.pumpWidget(
        phone(
          ApneDoctorsApp(routerConfig: r),
          overrides: [
            launchStoreProvider.overrideWithValue(store),
            codeVerifierProvider.overrideWithValue(FakeVerifier()),
            phoneCodeSenderProvider.overrideWithValue(FakeSender(next: const CodeSent())),
            basicsSaverProvider.overrideWithValue(FakeSaver()),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.enterText(codeInput, '482913');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(AboutYouScreen), findsNothing, reason: 'the a is still jumping for joy');
      await tester.pump(const Duration(milliseconds: 700));
      // mid-move: the code page steps aside while About you comes in
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(CodeScreen), findsNothing);
      expect(store.basicsDraft, isNotNull); // closing the app now comes back here
      expect(store.pendingCode, isNull);
      expect(r.canPop(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('the rules, on their own', () {
    test('ages are counted as the server counts them: this month’s birthday hasn’t come yet', () {
      final t = DateTime.utc(2026, 11, 27);
      expect(ageFrom(const BirthMonth(2004, 3), t), 22);
      expect(ageFrom(const BirthMonth(2004, 11), t), 21);
      expect(ageFrom(const BirthMonth(2004, 12), t), 21);
      expect(ageFrom(const AgeOnly(52), t), 52);
    });

    test('today is India’s date (IST)', () {
      expect(istToday(DateTime.utc(2026, 11, 30, 19)), DateTime.utc(2026, 12, 1));
      expect(istToday(DateTime.utc(2026, 11, 30, 18, 29)), DateTime.utc(2026, 11, 30));
    });

    test('GI-40: future dates and this year are caught before anything is sent', () {
      final t = DateTime.utc(2026, 11, 27);
      expect(checkBirth(const BirthMonth(2026, 12), t), BirthCheck.future);
      expect(checkBirth(const BirthMonth(2027, 1), t), BirthCheck.future);
      expect(checkBirth(const BirthMonth(2026, 3), t), BirthCheck.thisYear);
      expect(checkBirth(const BirthMonth(2025, 12), t), BirthCheck.ok);
    });

    test('names: any script, with the marks names use; not digits or symbols', () {
      for (final ok in ['Priya', 'प्रिया', 'ਪ੍ਰਿਯਾ', 'Mary-Ann', 'D’Souza', "O'Brien", 'K. Ramesh', 'Ánh']) {
        expect(NameRules.ok(ok), isTrue, reason: ok);
      }
      for (final bad in ['Priya2', 'p@riya', '-Priya', '.', 'Priya 🙂', 'a' * 41]) {
        expect(NameRules.ok(bad), isFalse, reason: bad);
      }
      expect(NameRules.bad(''), isFalse); // empty is not a mistake, just not done yet
      expect(NameRules.tidy('  priya   shah '), 'Priya Shah');
      expect(NameRules.tidy('van der Berg'), 'van der Berg'); // typed with care: kept exactly
      expect(NameRules.friendly('priya rani'), 'Priya');
    });

    test('what is sent: names tidied, an empty last name as nothing, an estimate as an age', () {
      final p = const Basics(
        firstName: ' priya ',
        lastName: '  ',
        gender: Gender.another,
        birth: AgeOnly(40),
      ).toParams();
      expect(p, {
        'first_name': 'Priya',
        'last_name': null,
        'gender': 'another',
        'birth_year': null,
        'birth_month': null,
        'age': 40,
        'confirm_over_100': false,
      });
      expect(const Basics.birthOnly(BirthMonth(2017, 4)).toParams()['first_name'], isNull);
    });

    test('the server’s answers, in plain words', () {
      PostgrestException e(String m) => PostgrestException(message: m, code: '22023');
      expect(saveResultFor(e('age_blocked')), isA<TooYoung>());
      expect((saveResultFor(e('exact_birth_needed')) as SaveRefused).kind, Refusal.exactBirthNeeded);
      expect((saveResultFor(e('birth_date_locked')) as SaveRefused).kind, Refusal.birthLocked);
      expect((saveResultFor(e('confirm_age')) as SaveRefused).kind, Refusal.confirmAge);
      expect((saveResultFor(e('birth_invalid')) as SaveRefused).kind, Refusal.birthInvalid);
      expect((saveResultFor(e('name_needed')) as SaveRefused).kind, Refusal.nameNeeded);
      // not there yet (not deployed), signed out, anything else: try again
      final missing = saveResultFor(const PostgrestException(message: 'Could not find the function', code: 'PGRST202'));
      expect((missing as SaveFailed).message, SendCopy.unreachable);
      expect(saveResultFromReply({'result': 'under_13'}), isA<TooYoung>());
      final ok = saveResultFromReply({'result': 'ok', 'next_step': 'parent', 'age_band': '13-17'}) as Saved;
      expect([ok.nextStep, ok.teen], ['parent', true]);
    });

    test('a draft survives the round trip', () {
      const d = BasicsDraft(
        step: 'gender',
        first: 'Priya',
        last: 'Shah',
        month: 3,
        year: 2004,
        gender: Gender.undisclosed,
      );
      final back = BasicsDraft.fromJson(d.toJson())!;
      expect(
        [back.step, back.first, back.last, back.month, back.year, back.gender],
        ['gender', 'Priya', 'Shah', 3, 2004, Gender.undisclosed],
      );
      expect(BasicsDraft.fromJson('not json'), isNull);
    });
  });
}
