// Renders About you's steps as still images, for looking at the design.
//
//   flutter test tool/frames/about_you_shots_test.dart --dart-define=OUT=/path/to/dir [--dart-define=DPR=2]
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/about_you/about_you_screen.dart';
import 'package:apnedoctors/features/about_you/basics.dart';

import '../../test/support/about_driver.dart';
import '../../test/support/fonts.dart';
import '../../test/support/get_started_driver.dart';

const _out = String.fromEnvironment('OUT');
const _dpr = int.fromEnvironment('DPR', defaultValue: 1);

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await b.toImage(pixelRatio: _dpr.toDouble());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Directory(_out).createSync(recursive: true);
  });

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    final tag = '${size.width.toInt()}';
    testWidgets('steps $tag', (tester) async {
      final key = GlobalKey();
      await pumpAboutYou(tester, size: size, key: key, reduced: true);
      tester.view.devicePixelRatio = _dpr.toDouble();
      tester.view.physicalSize = size * _dpr.toDouble();
      await tester.pump(const Duration(seconds: 1));
      await _shoot(tester, key, '${tag}_1_name_empty');
      await tester.enterText(firstNameInput, 'priya');
      await setKeyboard(tester, size.height < 700 ? 260 : 300);
      await tester.pump(const Duration(milliseconds: 600));
      await _shoot(tester, key, '${tag}_2_name_typed_kb');
      await setKeyboard(tester, 0);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 600));
      await _shoot(tester, key, '${tag}_3_name_typed');
      await tapContinue(tester);
      await _shoot(tester, key, '${tag}_4_birth');
      await tester.tap(find.text(AboutCopy.next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await _shoot(tester, key, '${tag}_5_confirm');
      await tester.tap(find.text(AboutCopy.yes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await _shoot(tester, key, '${tag}_6_gender');
      await tester.tap(find.text(Gender.woman.label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _shoot(tester, key, '${tag}_7_gender_picked');
      await tapContinue(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _shoot(tester, key, '${tag}_8_done');
    });

    testWidgets('age $tag', (tester) async {
      final key = GlobalKey();
      await pumpAboutYou(
        tester,
        size: size,
        key: key,
        draft: const BasicsDraft(step: 'age', first: 'Ramesh', ageOnly: true, age: 52),
      );
      tester.view.devicePixelRatio = _dpr.toDouble();
      tester.view.physicalSize = size * _dpr.toDouble();
      await tester.pump(const Duration(seconds: 1));
      await _shoot(tester, key, '${tag}_9_age');
    });

    testWidgets('under 13 $tag', (tester) async {
      final key = GlobalKey();
      await pumpAboutYou(tester, size: size, key: key, start: AboutStep.tooYoung);
      tester.view.devicePixelRatio = _dpr.toDouble();
      tester.view.physicalSize = size * _dpr.toDouble();
      await tester.pump(const Duration(seconds: 1));
      await _shoot(tester, key, '${tag}_10_too_young');
    });
  }
}
