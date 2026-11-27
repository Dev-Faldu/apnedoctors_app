import 'dart:async';

import 'package:clock/clock.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/get_started/code_screen.dart';
import 'package:apnedoctors/features/get_started/code_verifier.dart';
import 'package:apnedoctors/features/get_started/phone_code_sender.dart';
import 'package:apnedoctors/features/launch/launch_store.dart';
import 'package:apnedoctors/shared/indian_phone.dart';

import 'get_started_driver.dart';
import 'harness.dart';

/// Stands in for Supabase's code check: [right] signs in, anything else is rejected. With [next] set, every check
/// answers with that instead; with [hold], checks wait until the test completes [pending].
class FakeVerifier implements CodeVerifier {
  FakeVerifier({this.right = '482913', this.next, this.hold = false});
  final String right;
  VerifyResult? next;
  bool hold;
  final codes = <String>[];
  Completer<VerifyResult>? pending;

  @override
  Future<VerifyResult> verify(PhoneOk phone, String code) {
    codes.add(code);
    if (hold) {
      pending = Completer<VerifyResult>();
      return pending!.future;
    }
    return Future.value(next ?? (code == right ? const Verified() : const VerifyRejected()));
  }
}

final testPhone = parseIndianPhone('98765 43210') as PhoneOk;

/// Opens the code screen on its own, as if a code was just sent.
Future<MemoryLaunchStore> pumpCodeScreen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  FakeVerifier? verifier,
  PhoneCodeSender? sender,
  bool reduced = true,
  double textScale = 1,
  DateTime? sentAt,
  int sends = 1,
  Key? key,
  VoidCallback? onBack,
  VoidCallback? onChange,
}) async {
  setPhone(tester, size);
  final store = MemoryLaunchStore();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: phone(
        CodeScreen(
          arrival: CodeArrival(phone: testPhone, sentAt: sentAt ?? clock.now(), sends: sends),
          onBack: onBack,
          onChange: onChange,
        ),
        overrides: [
          codeVerifierProvider.overrideWithValue(verifier ?? FakeVerifier()),
          phoneCodeSenderProvider.overrideWithValue(sender ?? FakeSender(next: const CodeSent())),
          launchStoreProvider.overrideWithValue(store),
        ],
        reducedMotion: reduced,
        textScale: textScale,
      ),
    ),
  );
  await tester.pump();
  return store;
}

Finder get codeInput => find.descendant(of: find.byType(CodeScreen), matching: find.byType(EditableText));
