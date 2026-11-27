import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/backend.dart';
import '../../shared/indian_phone.dart';
import 'phone_code_sender.dart';

/// What happened when we checked a code.
sealed class VerifyResult {
  const VerifyResult();
}

/// The code was right: the person is signed in (a session is saved on the phone).
class Verified extends VerifyResult {
  const Verified();
}

/// Not accepted. Supabase answers the same for a wrong code and an expired one, so the screen tells them apart by
/// how long ago the code was sent.
class VerifyRejected extends VerifyResult {
  const VerifyRejected();
}

/// Too many tries for now; try again after [wait] (GI-26). Null when the server didn't say.
class VerifyWait extends VerifyResult {
  const VerifyWait(this.wait);
  final Duration? wait;
}

/// It didn't work for another reason; [message] says what to do next (GI-66, GI-67).
class VerifyFailed extends VerifyResult {
  const VerifyFailed(this.message);
  final String message;
}

/// Checks a one-time code. GS2 asks; tests swap in their own.
abstract class CodeVerifier {
  Future<VerifyResult> verify(PhoneOk phone, String code);
}

/// Checks through Supabase phone sign-in (`verifyOTP`, type sms). Success saves the session on the phone.
class SupabaseCodeVerifier implements CodeVerifier {
  SupabaseCodeVerifier(this.client, {this.timeout = const Duration(seconds: 30)});
  final SupabaseClient client;
  final Duration timeout;

  @override
  Future<VerifyResult> verify(PhoneOk phone, String code) async {
    try {
      final res = await client.auth.verifyOTP(phone: phone.e164, token: code, type: OtpType.sms).timeout(timeout);
      return res.session != null ? const Verified() : const VerifyRejected();
    } on AuthException catch (e) {
      return verifyResultFor(e);
    } on TimeoutException {
      return const VerifyFailed(SendCopy.unreachable);
    } catch (_) {
      return const VerifyFailed(SendCopy.unreachable);
    }
  }
}

/// Supabase's answer, in the person's words. Pure, so every case is tested.
VerifyResult verifyResultFor(AuthException e) {
  if (e is AuthRetryableFetchException || e.statusCode == null) return const VerifyFailed(SendCopy.unreachable);
  final code = e.code ?? '';
  final message = e.message.toLowerCase();
  if (e.statusCode == '429' || code.startsWith('over_')) {
    final s = RegExp(r'after (\d+) second').firstMatch(message);
    return VerifyWait(s == null ? null : Duration(seconds: int.parse(s.group(1)!)));
  }
  if (code == 'otp_expired' || e.statusCode == '403' || message.contains('expired') || message.contains('invalid')) {
    return const VerifyRejected();
  }
  return const VerifyFailed(SendCopy.unreachable);
}

final codeVerifierProvider = Provider<CodeVerifier>((ref) => SupabaseCodeVerifier(ref.read(supabaseProvider)));

/// How Supabase is set up for codes (Authentication → Phone): a code lives 60 s; a new one can be sent after 60 s.
abstract final class CodeRules {
  static const life = Duration(seconds: 60);

  /// Our own cap on wrong tries per code, so "2 tries left" is true (GI-25).
  static const tries = 3;

  /// The wait before each new code: the server's minute first, then longer.
  static Duration resendAfter(int sends) => switch (sends) {
    <= 1 => const Duration(seconds: 60),
    2 => const Duration(seconds: 120),
    _ => const Duration(seconds: 180),
  };

  /// When "Didn't get it?" offers its help (GI-28).
  static const helpAfter = Duration(seconds: 30);

  /// How long a sent code is waited for after the app is closed (GI-29).
  static const pendingLife = Duration(minutes: 10);
}

/// Everything the code screen needs from the phone screen: the number, when the code went, how many have gone, and
/// (for the move between the two) where the number stood and the shared clock of the toran and the a.
class CodeArrival {
  const CodeArrival({required this.phone, required this.sentAt, this.sends = 1, this.numberFrom, this.clockFrom = 0});

  final PhoneOk phone;
  final DateTime sentAt;
  final int sends;

  /// The phone number's digits on the phone screen, in screen coordinates: they fly up into the code screen.
  final Rect? numberFrom;

  /// The phone screen's clock, so the toran and the a keep their rhythm across the move.
  final double clockFrom;
}
