/// Indian mobile numbers, as people type and paste them (GI-20 to GI-23).
///
/// India only for the beta: ten digits starting 6–9, with or without +91, 91 or a leading 0, and any spaces,
/// dashes, dots or brackets. Anything else is refused before a code is ever sent.
sealed class PhoneParse {
  const PhoneParse();
}

/// A valid number. [e164] is `+91XXXXXXXXXX`.
class PhoneOk extends PhoneParse {
  const PhoneOk(this.national);

  /// The ten digits.
  final String national;

  String get e164 => '+91$national';

  /// `98765 43210`
  String get display => '${national.substring(0, 5)} ${national.substring(5)}';

  /// `+91 98•••••210`, for "Continue as …" and Welcome back.
  String get masked => '+91 ${national.substring(0, 2)}•••••${national.substring(7)}';
}

enum PhoneProblem {
  /// Nothing typed yet.
  empty,

  /// Not ten digits starting 6–9 (GI-21).
  notAMobile,

  /// Another country's number (GI-23).
  notIndian,
}

class PhoneBad extends PhoneParse {
  const PhoneBad(this.problem);
  final PhoneProblem problem;
}

PhoneParse parseIndianPhone(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const PhoneBad(PhoneProblem.empty);
  // only digits, spaces and the usual separators; letters mean it isn't a phone number
  if (RegExp(r'[^0-9+\s\-().]').hasMatch(trimmed)) return const PhoneBad(PhoneProblem.notAMobile);
  final plus = trimmed.startsWith('+') || trimmed.startsWith('00');
  var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (trimmed.startsWith('00')) digits = digits.substring(2);

  if (plus) {
    // an explicit country code: it has to be India's
    if (!digits.startsWith('91')) return const PhoneBad(PhoneProblem.notIndian);
    digits = digits.substring(2);
  } else if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length != 10 || !RegExp(r'^[6-9]').hasMatch(digits)) return const PhoneBad(PhoneProblem.notAMobile);
  return PhoneOk(digits);
}

/// The live hint when a number starts with 0–5 (GI-21): what an Indian mobile looks like.
const phoneStartHint = 'Indian mobiles start with 6, 7, 8 or 9.';

/// What the person sees for a problem (sentence case, says what to do next).
String phoneProblemText(PhoneProblem p) => switch (p) {
  PhoneProblem.empty => 'Enter your 10-digit mobile number.',
  PhoneProblem.notAMobile => 'That doesn’t look like an Indian mobile number.',
  PhoneProblem.notIndian => 'For now we can only send codes to Indian mobile numbers.',
};
