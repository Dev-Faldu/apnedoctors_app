import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/about_you/about_you_screen.dart';
import 'package:apnedoctors/features/about_you/basics.dart';
import 'package:apnedoctors/features/about_you/helpline.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';

import 'harness.dart';

/// Stands in for `public.set_basics`: counts the age the way the server does and answers like it. With [next] set,
/// every save answers with that instead; with [hold], saves wait until the test completes [pending].
class FakeSaver implements BasicsSaver {
  FakeSaver({this.next, this.hold = false});
  SaveResult? next;
  bool hold;
  final saved = <Basics>[];
  int signOuts = 0;
  Completer<SaveResult>? pending;

  @override
  Future<SaveResult> save(Basics basics) {
    saved.add(basics);
    if (hold) {
      pending = Completer<SaveResult>();
      return pending!.future;
    }
    final n = next;
    if (n != null) return Future.value(n);
    final years = ageFrom(basics.birth, istToday(clock.now()));
    if (years < AgeRules.minimum) return Future.value(const TooYoung());
    if (basics.firstName == null) return Future.value(const SaveRefused(Refusal.nameNeeded));
    final teen = years < 18;
    return Future.value(Saved(nextStep: teen ? 'parent' : 'data_consent', teen: teen));
  }

  @override
  Future<void> signOut() async => signOuts++;
}

/// Opens About you on its own, as if the code was just verified.
Future<({MemoryLaunchStore store, FakeSaver saver, List<String> calls, List<Saved> done})> pumpAboutYou(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  FakeSaver? saver,
  bool reduced = true,
  double textScale = 1,
  BasicsDraft? draft,
  AboutStep? start,
  Key? key,
}) async {
  setPhone(tester, size);
  final store = MemoryLaunchStore();
  final s = saver ?? FakeSaver();
  final calls = <String>[];
  final done = <Saved>[];
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: phone(
        AboutYouScreen(draft: draft, start: start, onDone: done.add),
        overrides: [
          basicsSaverProvider.overrideWithValue(s),
          launchStoreProvider.overrideWithValue(store),
          diallerProvider.overrideWithValue((n) async => calls.add(n)),
        ],
        reducedMotion: reduced,
        textScale: textScale,
      ),
    ),
  );
  await tester.pump();
  return (store: store, saver: s, calls: calls, done: done);
}

Finder get firstNameInput =>
    find.descendant(of: find.byType(AboutYouScreen), matching: find.byType(EditableText)).first;
Finder get lastNameInput => find.descendant(of: find.byType(AboutYouScreen), matching: find.byType(EditableText)).last;
Finder get continueButton => find.bySemanticsLabel(AboutCopy.next);

/// Taps Continue and lets the step change settle.
Future<void> tapContinue(WidgetTester tester) async {
  await tester.tap(find.text(AboutCopy.next));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
