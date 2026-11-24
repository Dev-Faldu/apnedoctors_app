// Renders the opening frame by frame to PNGs for comparison with the design board.
//
//   flutter test tool/frames/capture_test.dart --dart-define=OUT=/path/to/dir \
//     --dart-define=W=390 --dart-define=H=844 --dart-define=FPS=60 --dart-define=SECONDS=10.5
//
// Frame i is the opening clock at i / FPS seconds, the same timestamps tools/board_frames.js uses.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/opening/opening_screen.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';

import '../../test/support/fonts.dart';
import '../../test/support/harness.dart';

const _out = String.fromEnvironment('OUT');
const _w = int.fromEnvironment('W', defaultValue: 390);
const _h = int.fromEnvironment('H', defaultValue: 844);
const _fps = int.fromEnvironment('FPS', defaultValue: 60);
const _seconds = String.fromEnvironment('SECONDS', defaultValue: '10.5');
const _dpr = String.fromEnvironment('DPR', defaultValue: '1');
const _chip = bool.fromEnvironment('CHIP', defaultValue: true);

void main() {
  testWidgets('capture opening frames', (tester) async {
    await loadAppFonts();
    final dpr = double.parse(_dpr);
    setPhone(tester, Size(_w.toDouble(), _h.toDouble()), dpr: dpr);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: phone(OpeningScreen(doctorsOnline: _chip ? boardDoctorsOnline : null)),
      ),
    );
    final dir = Directory(_out)..createSync(recursive: true);
    final n = (double.parse(_seconds) * _fps).round();
    final step = Duration(microseconds: (1e6 / _fps).round());
    for (var i = 0; i <= n; i++) {
      if (i > 0) await tester.pump(step);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: dpr);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/f_${i.toString().padLeft(4, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
