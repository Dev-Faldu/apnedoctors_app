// Renders code → About you frame by frame: the right code, the celebration, the page turns to About you, a name typed,
// the birthday wheel turned, the confirm sheet (the a hops onto it), a gender chosen, saved.
//
//   flutter test tool/frames/about_you_flow_test.dart --dart-define=OUT=/path/to/dir [--dart-define=DPR=2]
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/about_you/about_you_screen.dart';
import 'package:apnedoctors/features/about_you/basics.dart';
import 'package:apnedoctors/features/about_you/birth_wheel.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';

import '../../test/support/about_driver.dart';
import '../../test/support/code_driver.dart';
import '../../test/support/fonts.dart';
import '../../test/support/get_started_driver.dart';
import '../../test/support/harness.dart';

const _out = String.fromEnvironment('OUT');
const _dpr = int.fromEnvironment('DPR', defaultValue: 1);

void main() {
  testWidgets('code → About you → saved', (tester) async {
    await loadAppFonts();
    Directory(_out).createSync(recursive: true);
    setPhone(tester, const Size(390, 844), dpr: _dpr.toDouble());
    final store = MemoryLaunchStore()..pendingCode = PendingCode(e164: '+919876543210', sentAt: clock.now());
    final router = GoRouter(
      initialLocation: Routes.code,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: Routes.getStarted, builder: (context, state) => const SizedBox()),
        GoRoute(path: Routes.code, pageBuilder: codePage),
        GoRoute(path: Routes.aboutYou, pageBuilder: aboutYouPage),
      ],
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: phone(
          ApneDoctorsApp(routerConfig: router),
          overrides: [
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            launchStoreProvider.overrideWithValue(store),
            phoneCodeSenderProvider.overrideWithValue(FakeSender(next: const CodeSent())),
            codeVerifierProvider.overrideWithValue(FakeVerifier()),
            basicsSaverProvider.overrideWithValue(FakeSaver()),
          ],
        ),
      ),
    );
    var frame = 0;
    Future<void> shoot() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await b.toImage(pixelRatio: _dpr.toDouble());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/f_${(frame++).toString().padLeft(4, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> play(double seconds) async {
      for (var i = 0; i < (seconds * 30).round(); i++) {
        await tester.pump(const Duration(microseconds: 33333));
        await shoot();
      }
    }

    Future<void> keyboard(double h) async {
      tester.view.viewInsets = FakeViewPadding(bottom: h * _dpr);
      await play(.3);
    }

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.enterText(codeInput, '482913');
    await play(3.0); // verified, the a jumps, petals, the page turns to About you
    await keyboard(335);
    for (final name in ['P', 'Pr', 'Pri', 'Priy', 'Priya']) {
      await tester.enterText(firstNameInput, name);
      await play(.16);
    }
    await play(.8);
    await keyboard(0);
    await tester.tap(find.text(AboutCopy.next));
    await play(1.2);
    final years = find.descendant(of: find.byType(BirthWheel), matching: find.byType(ListWheelScrollView)).last;
    final g = await tester.startGesture(tester.getCenter(years));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(0, 11));
      await play(1 / 30);
    }
    await g.up();
    await play(1.0);
    await tester.tap(find.text(AboutCopy.next));
    await play(1.4); // the sheet rises, the a hops down onto it
    await tester.tap(find.text(AboutCopy.yes));
    await play(1.2);
    await tester.tap(find.text(Gender.woman.label));
    await play(1.0);
    await tester.tap(find.text(AboutCopy.next));
    await play(2.6); // saved: nice to meet you, petals
  }, timeout: const Timeout(Duration(minutes: 20)));
}
