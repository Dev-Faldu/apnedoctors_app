import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/backend/online.dart';
import 'package:apnedoctors/features/get_started/get_started_screen.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/shared/indian_phone.dart';

import 'harness.dart';

/// Stands in for Supabase in widget tests. With [next] set, every send answers at once with it; otherwise the send
/// waits until the test completes [pending].
class FakeSender implements PhoneCodeSender {
  FakeSender({this.next});
  SendResult? next;
  final calls = <PhoneOk>[];
  Completer<SendResult>? pending;

  @override
  Future<SendResult> send(PhoneOk phone) {
    calls.add(phone);
    final n = next;
    if (n != null) return Future.value(n);
    pending = Completer<SendResult>();
    return pending!.future;
  }
}

/// The keyboard heights the G03 board draws (390 × 844: 291; 360 × 640: 258).
double boardKeyboard(Size size) => size.height < 700 ? 258 : 291;

/// Opens Get started on its own, the way the router shows it.
Future<void> pumpGetStarted(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool online = true,
  PhoneCodeSender? sender,
  bool reduced = true,
  double textScale = 1,
  bool entrance = false,
  Key? key,
  VoidCallback? onBack,
  VoidCallback? onSignIn,
  ValueChanged<PhoneOk>? onCodeSent,
}) async {
  setPhone(tester, size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: phone(
        GetStartedScreen(entrance: entrance, onBack: onBack, onSignIn: onSignIn, onCodeSent: onCodeSent),
        overrides: [
          onlineProvider.overrideWith((ref) => Stream.value(online)),
          phoneCodeSenderProvider.overrideWithValue(sender ?? FakeSender()),
        ],
        reducedMotion: reduced,
        textScale: textScale,
      ),
    ),
  );
  await tester.pump(); // the online stream's first value; the screen's clock starts here
}

/// Opens or closes the (simulated) keyboard.
Future<void> setKeyboard(WidgetTester tester, double height) async {
  tester.view.viewInsets = FakeViewPadding(bottom: height * tester.view.devicePixelRatio);
  // frame by frame, as a phone draws them: the compact fold settles, then Send code is kept in view
  for (var i = 0; i < 45; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder get phoneInput => find.byType(EditableText);
