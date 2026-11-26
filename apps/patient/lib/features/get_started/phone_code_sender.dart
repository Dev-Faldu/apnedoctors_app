import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/backend.dart';
import '../../shared/indian_phone.dart';

/// What happened when we asked for a code.
sealed class SendResult {
  const SendResult();
}

/// The code is on its way (or, for a Supabase test number, ready with its fixed code).
class CodeSent extends SendResult {
  const CodeSent();
}

/// Too many sends: try again after [wait] (GI-26). Null when the server didn't say how long.
class SendWait extends SendResult {
  const SendWait(this.wait);
  final Duration? wait;
}

/// It didn't work; [message] says what to do next, in plain words (GI-66, GI-67).
class SendFailed extends SendResult {
  const SendFailed(this.message, {this.wrongNumber = false});
  final String message;

  /// The server refused the number itself.
  final bool wrongNumber;
}

/// Texts a one-time code to a phone number. GS1 asks for one; tests swap in their own.
abstract class PhoneCodeSender {
  Future<SendResult> send(PhoneOk phone);
}

/// Copy for the send failures (sentence case, says what to do next).
abstract final class SendCopy {
  static const unreachable = 'We can’t reach ApneDoctors right now. Try again in a minute.';
  static const smsFailed = 'We couldn’t text a code to this number right now. Try again in a few minutes.';
  static const tooManyLater = 'Too many tries. Try again a little later.';

  /// GI-26: the real wait, never a raw error. "Try again in 37 seconds." / "in 12 minutes."
  static String tooMany(Duration wait) {
    final s = wait.inSeconds;
    if (s < 60) return 'Too many tries. Try again in ${s <= 1 ? '1 second' : '$s seconds'}.';
    final m = (s / 60).ceil();
    return 'Too many tries. Try again in ${m == 1 ? '1 minute' : '$m minutes'}.';
  }
}

/// Sends through Supabase phone sign-in (`signInWithOtp`, SMS). Creates the account on first use (Get started);
/// a number that already has one simply gets a code, and GS2 signs them in (GI-33).
class SupabasePhoneCodeSender implements PhoneCodeSender {
  SupabasePhoneCodeSender(this.client, {this.timeout = const Duration(seconds: 30)});
  final SupabaseClient client;

  /// After this the send counts as failed and the button comes back (GI-66).
  final Duration timeout;

  @override
  Future<SendResult> send(PhoneOk phone) async {
    try {
      await client.auth.signInWithOtp(phone: phone.e164, shouldCreateUser: true).timeout(timeout);
      return const CodeSent();
    } on AuthException catch (e) {
      return sendResultFor(e);
    } on TimeoutException {
      return const SendFailed(SendCopy.unreachable);
    } catch (_) {
      return const SendFailed(SendCopy.unreachable);
    }
  }
}

/// Supabase's answer, in the person's words. Pure, so every case is tested.
SendResult sendResultFor(AuthException e) {
  if (e is AuthRetryableFetchException || e.statusCode == null) return const SendFailed(SendCopy.unreachable);
  final code = e.code ?? '';
  final message = e.message.toLowerCase();
  if (e.statusCode == '429' || code.startsWith('over_')) {
    // "For security purposes, you can only request this after 37 seconds."
    final m = RegExp(r'after (\d+) second').firstMatch(message);
    return SendWait(m == null ? null : Duration(seconds: int.parse(m.group(1)!)));
  }
  if (code == 'validation_failed' || message.contains('invalid phone')) {
    return const SendFailed(SendCopy.smsFailed, wrongNumber: true);
  }
  if (code == 'sms_send_failed' ||
      code == 'phone_provider_disabled' ||
      message.contains('sms') ||
      message.contains('provider')) {
    return const SendFailed(SendCopy.smsFailed);
  }
  return const SendFailed(SendCopy.unreachable);
}

final phoneCodeSenderProvider = Provider<PhoneCodeSender>((ref) => SupabasePhoneCodeSender(ref.read(supabaseProvider)));
