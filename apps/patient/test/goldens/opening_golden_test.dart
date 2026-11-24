// Golden frames of the opening and Welcome at 360x640 and 390x844.
// Regenerate after an approved design change: flutter test --update-goldens test/goldens
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/opening/opening_screen.dart';
import 'package:apnedoctors/features/welcome/doctors_online.dart';
import 'package:apnedoctors/features/welcome/welcome_host.dart';

import '../support/fonts.dart';
import '../support/harness.dart';

const _sizes = [Size(360, 640), Size(390, 844)];

/// One frame per beat of the board: bloom, wake, glide, writing, smile, hand-off, rise, arch, settled.
const _beats = [0.3, 1.2, 2.3, 3.4, 4.8, 6.0, 7.0, 8.0, 10.0];

String _name(Size s) => '${s.width.toInt()}x${s.height.toInt()}';

void main() {
  setUpAll(loadAppFonts);

  for (final size in _sizes) {
    testWidgets('opening beats ${_name(size)}', (tester) async {
      setPhone(tester, size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: phone(const OpeningScreen(doctorsOnline: boardDoctorsOnline)),
        ),
      );
      var frames = 0;
      for (final t in _beats) {
        final target = (t * 60).round();
        while (frames < target) {
          await tester.pump(const Duration(microseconds: 16667));
          frames++;
        }
        await expectLater(find.byKey(key), matchesGoldenFile('opening/${_name(size)}_t${t.toStringAsFixed(1)}.png'));
      }
    });

    testWidgets('welcome, reduced motion ${_name(size)}', (tester) async {
      setPhone(tester, size);
      await tester.pumpWidget(
        phone(const WelcomeHost(reduced: true, doctorsOnline: boardDoctorsOnline), reducedMotion: true),
      );
      await expectLater(find.byType(WelcomeHost), matchesGoldenFile('welcome/${_name(size)}_reduced.png'));
    });

    testWidgets('welcome, no live doctor count yet ${_name(size)}', (tester) async {
      setPhone(tester, size);
      await tester.pumpWidget(phone(const WelcomeHost(reduced: true), reducedMotion: true));
      await expectLater(find.byType(WelcomeHost), matchesGoldenFile('welcome/${_name(size)}_no_chip.png'));
    });

    testWidgets('welcome, opened before ${_name(size)}', (tester) async {
      setPhone(tester, size);
      await tester.pumpWidget(phone(const WelcomeHost(doctorsOnline: boardDoctorsOnline)));
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
      await expectLater(find.byType(WelcomeHost), matchesGoldenFile('welcome/${_name(size)}_standalone_t3.0.png'));
    });
  }
}
