// Renders the walk through Welcome's doorway into Get started, and back, frame by frame.
//
//   flutter test tool/frames/walk_through_test.dart --dart-define=OUT=/path/to/dir [--dart-define=W=390 --dart-define=H=844 --dart-define=DPR=2]
//
// Writes <OUT>/f_0000.png …: Welcome settled, the tap on Get started, the walk in (0.9 s), a moment of typing, then
// Back (0.7 s). 30 frames a second.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:apnedoctors/app/app.dart';
import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/features/welcome/doorway_hand_off.dart';
import 'package:apnedoctors/features/welcome/welcome_host.dart';

import '../../test/support/fonts.dart';
import '../../test/support/get_started_driver.dart';
import '../../test/support/harness.dart';

const _out = String.fromEnvironment('OUT');
const _w = int.fromEnvironment('W', defaultValue: 390);
const _h = int.fromEnvironment('H', defaultValue: 844);
const _dpr = int.fromEnvironment('DPR', defaultValue: 1);

void main() {
  testWidgets('walk through the doorway', (tester) async {
    await loadAppFonts();
    Directory(_out).createSync(recursive: true);
    setPhone(tester, Size(_w.toDouble(), _h.toDouble()), dpr: _dpr.toDouble());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => WelcomeHost(
            doctorsOnline: boardDoctorsOnline,
            onGetStarted: () => context.push(Routes.getStarted, extra: DoorwayHandOff.take()),
          ),
        ),
        GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
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
            phoneCodeSenderProvider.overrideWithValue(FakeSender()),
          ],
        ),
      ),
    );
    var frame = 0;
    Future<void> shoot() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _dpr.toDouble());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/f_${(frame++).toString().padLeft(4, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> play(double seconds) async {
      final n = (seconds * 30).round();
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(microseconds: 33333));
        await shoot();
      }
    }

    // Welcome, settled
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await play(.4);
    await tester.tap(find.text('Get started'));
    await play(1.6);
    await tester.enterText(phoneInput, '98765');
    await play(.5);
    await tester.enterText(phoneInput, '9876543210');
    await play(1.0);
    FocusManager.instance.primaryFocus?.unfocus();
    await play(.3);
    await tester.tap(find.bySemanticsLabel('Back to Welcome'));
    await play(1.2);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
