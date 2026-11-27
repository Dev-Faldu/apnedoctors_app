// Renders the phone screen → code screen flow frame by frame: type a number, send, the number flies up into the code
// screen, a wrong code, the right code, verified.
//
//   flutter test tool/frames/code_flow_test.dart --dart-define=OUT=/path/to/dir [--dart-define=DPR=2]
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';

import '../../test/support/code_driver.dart';
import '../../test/support/fonts.dart';
import '../../test/support/get_started_driver.dart';
import '../../test/support/harness.dart';

const _out = String.fromEnvironment('OUT');
const _dpr = int.fromEnvironment('DPR', defaultValue: 1);

void main() {
  testWidgets('phone → code → verified', (tester) async {
    await loadAppFonts();
    Directory(_out).createSync(recursive: true);
    setPhone(tester, const Size(390, 844), dpr: _dpr.toDouble());
    final router = GoRouter(
      initialLocation: Routes.getStarted,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
        GoRoute(path: Routes.code, pageBuilder: codePage),
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
            phoneCodeSenderProvider.overrideWithValue(FakeSender(next: const CodeSent())),
            codeVerifierProvider.overrideWithValue(FakeVerifier()),
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

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.enterText(phoneInput, '9876543210');
    FocusManager.instance.primaryFocus?.unfocus();
    await play(.6);
    await tester.tap(find.text('Send code'));
    await play(2.0); // sent, the move, the code screen settles
    await tester.enterText(find.byType(EditableText).last, '48');
    await play(.35);
    await tester.enterText(find.byType(EditableText).last, '482931');
    await play(1.8); // checking, wrong, cleared
    await tester.enterText(find.byType(EditableText).last, '482913');
    await play(2.4); // checking, verified, petals
  }, timeout: const Timeout(Duration(minutes: 20)));
}
