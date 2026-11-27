import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/backend.dart';
import '../get_started/phone_code_sender.dart' show SendCopy;

/// About you (GS3 · G7): what we ask, how ages are counted, and how it is saved (`public.set_basics`).

/// The four answers to "which fits you best?", with the values the server keeps.
enum Gender {
  woman('woman', 'Woman'),
  man('man', 'Man'),
  another('another', 'Something else'),
  undisclosed('undisclosed', 'I’d rather not say');

  const Gender(this.server, this.label);
  final String server;
  final String label;
}

/// When someone was born: a month and year, or (adults only) just an age, kept as an estimate (GI-46).
@immutable
sealed class Birth {
  const Birth();
}

class BirthMonth extends Birth {
  const BirthMonth(this.year, this.month);
  final int year;

  /// 1–12.
  final int month;

  @override
  bool operator ==(Object other) => other is BirthMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class AgeOnly extends Birth {
  const AgeOnly(this.age);
  final int age;

  @override
  bool operator ==(Object other) => other is AgeOnly && other.age == age;

  @override
  int get hashCode => age.hashCode;
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Today's date where the server counts ages: India (IST, UTC+5:30). Only the date is meaningful.
DateTime istToday(DateTime now) {
  final t = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(t.year, t.month, t.day);
}

/// Whole years, as the server counts them (`private.age_from`): a birthday in this month counts as not yet, and an
/// estimate counts as its year.
int ageFrom(Birth birth, DateTime today) => switch (birth) {
  AgeOnly(:final age) => age,
  BirthMonth(:final year, :final month) => today.year - year - (month >= today.month ? 1 : 0),
};

/// What a birth month and year means before anyone confirms it (GI-40).
enum BirthCheck {
  ok,

  /// Later than this month.
  future,

  /// This year: almost always a wheel that wasn't turned.
  thisYear,
}

BirthCheck checkBirth(BirthMonth b, DateTime today) {
  if (b.year > today.year || (b.year == today.year && b.month > today.month)) return BirthCheck.future;
  if (b.year == today.year) return BirthCheck.thisYear;
  return BirthCheck.ok;
}

/// Ages the app asks about.
abstract final class AgeRules {
  /// Under this, See you at 13 (G12).
  static const minimum = 13;

  /// An age on its own is only taken from adults; under 18 we need the birth month and year (GI-46).
  static const estimateFrom = 18;

  /// Above this, the server asks for a second yes (GI-40).
  static const confirmAbove = 100;

  /// The oldest birth year on the wheel, and the oldest age on its own (the server's limit).
  static const oldest = 120;
}

/// Names: letters in any script, with spaces, dots, apostrophes and hyphens between them (Mary-Ann, D’Souza,
/// K. Ramesh). Up to 40 characters, as the server allows.
abstract final class NameRules {
  static const maxLength = 40;
  static final _ok = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'’\-]*$", unicode: true);

  static String clean(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// True when [raw] (trimmed) is a usable name. Empty is not.
  static bool ok(String raw) {
    final n = clean(raw);
    return n.isNotEmpty && n.length <= maxLength && _ok.hasMatch(n);
  }

  /// True when [raw] has something in it that can't be part of a name (a digit, @, emoji…).
  static bool bad(String raw) => clean(raw).isNotEmpty && !ok(raw);

  /// As it is kept: cleaned, and if it was typed all in small letters, each word starts with a capital
  /// ("priya shah" → "Priya Shah"). Anything typed with capitals is kept exactly ("van der Berg", "DSouza").
  static String tidy(String raw) {
    final n = clean(raw);
    if (n != n.toLowerCase()) return n;
    return n.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  /// How the a says it: the first word, first letter up ("priya" → "Priya").
  static String friendly(String raw) {
    final n = clean(raw);
    if (n.isEmpty) return '';
    final first = n.split(' ').first;
    return first[0].toUpperCase() + first.substring(1);
  }
}

/// Everything About you sends at once.
@immutable
class Basics {
  const Basics({
    required this.firstName,
    this.lastName = '',
    required this.gender,
    required this.birth,
    this.confirmOver100 = false,
  });

  /// Only the birth date: the check for under-13s, which keeps nothing else about a child (GI-41).
  const Basics.birthOnly(this.birth) : firstName = null, lastName = '', gender = null, confirmOver100 = false;

  final String? firstName;
  final String lastName;
  final Gender? gender;
  final Birth birth;
  final bool confirmOver100;

  Map<String, Object?> toParams() => {
    'first_name': firstName == null ? null : NameRules.tidy(firstName!),
    'last_name': NameRules.clean(lastName).isEmpty ? null : NameRules.tidy(lastName),
    'gender': gender?.server,
    'birth_year': switch (birth) {
      BirthMonth(:final year) => year,
      AgeOnly() => null,
    },
    'birth_month': switch (birth) {
      BirthMonth(:final month) => month,
      AgeOnly() => null,
    },
    'age': switch (birth) {
      AgeOnly(:final age) => age,
      BirthMonth() => null,
    },
    'confirm_over_100': confirmOver100,
  };
}

/// About you, part-way through: kept on the phone as it changes, so closing the app (or going back a step) keeps
/// everything typed and chosen (GI-05, GI-64). Never sent anywhere.
@immutable
class BasicsDraft {
  const BasicsDraft({
    this.step = 'name',
    this.first = '',
    this.last = '',
    this.month,
    this.year,
    this.ageOnly = false,
    this.age,
    this.gender,
  });

  /// 'name', 'birth', 'age' or 'gender'.
  final String step;
  final String first;
  final String last;
  final int? month;
  final int? year;
  final bool ageOnly;
  final int? age;
  final Gender? gender;

  String toJson() => jsonEncode({
    'step': step,
    'first': first,
    'last': last,
    'month': ?month,
    'year': ?year,
    'ageOnly': ageOnly,
    'age': ?age,
    'gender': ?gender?.server,
  });

  static BasicsDraft? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final g = m['gender'] as String?;
      return BasicsDraft(
        step: (m['step'] as String?) ?? 'name',
        first: (m['first'] as String?) ?? '',
        last: (m['last'] as String?) ?? '',
        month: m['month'] as int?,
        year: m['year'] as int?,
        ageOnly: (m['ageOnly'] as bool?) ?? false,
        age: m['age'] as int?,
        gender: g == null ? null : Gender.values.where((x) => x.server == g).firstOrNull,
      );
    } catch (_) {
      return null;
    }
  }
}

/// What happened when About you was saved.
sealed class SaveResult {
  const SaveResult();
}

/// Saved. [nextStep] is where onboarding goes now ('parent' for a teen waiting for a parent, else 'data_consent').
class Saved extends SaveResult {
  const Saved({required this.nextStep, required this.teen});
  final String nextStep;
  final bool teen;
}

/// Under 13 (or this account is already waiting out its 24 hours): See you at 13. Nothing was kept (GI-41).
class TooYoung extends SaveResult {
  const TooYoung();
}

/// The server turned one answer down; the screen goes back to that question with [kind]'s words.
class SaveRefused extends SaveResult {
  const SaveRefused(this.kind);
  final Refusal kind;
}

/// It didn't work; [message] says what to do next (GI-66, GI-67).
class SaveFailed extends SaveResult {
  const SaveFailed(this.message);
  final String message;
}

enum Refusal {
  nameNeeded,
  genderNeeded,
  birthInvalid,

  /// An age on its own under 18 (GI-46).
  exactBirthNeeded,

  /// Over 100 without the second yes (GI-40).
  confirmAge,

  /// A birth date was saved before and this one is different (GI-42).
  birthLocked,
}

/// Saves About you. The screen asks; tests swap in their own.
abstract class BasicsSaver {
  Future<SaveResult> save(Basics basics);

  /// Signs out on this phone (after See you at 13).
  Future<void> signOut();
}

/// Saves through `public.set_basics`, which checks every rule again on the server and counts the age in IST.
class SupabaseBasicsSaver implements BasicsSaver {
  SupabaseBasicsSaver(this.client, {this.timeout = const Duration(seconds: 20)});
  final SupabaseClient client;
  final Duration timeout;

  @override
  Future<SaveResult> save(Basics basics) async {
    try {
      final res = await client.rpc<dynamic>('set_basics', params: basics.toParams()).timeout(timeout);
      return saveResultFromReply(res);
    } on PostgrestException catch (e) {
      return saveResultFor(e);
    } on TimeoutException {
      return const SaveFailed(SendCopy.unreachable);
    } catch (_) {
      return const SaveFailed(SendCopy.unreachable);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut(scope: SignOutScope.local).timeout(timeout);
    } catch (_) {
      // the session on this phone is cleared even when the server can't be told
    }
  }
}

/// `{"result": "ok", "next_step": "data_consent", "age_band": "18+"}` or `{"result": "under_13", …}`.
SaveResult saveResultFromReply(Object? reply) {
  if (reply is! Map) return const SaveFailed(SendCopy.unreachable);
  if (reply['result'] == 'under_13') return const TooYoung();
  if (reply['result'] == 'ok') {
    return Saved(nextStep: '${reply['next_step'] ?? 'data_consent'}', teen: reply['age_band'] == '13-17');
  }
  return const SaveFailed(SendCopy.unreachable);
}

/// The server's refusal, as something the screen can act on. Pure, so every case is tested.
SaveResult saveResultFor(PostgrestException e) => switch (e.message) {
  'age_blocked' => const TooYoung(),
  'name_needed' => const SaveRefused(Refusal.nameNeeded),
  'gender_needed' => const SaveRefused(Refusal.genderNeeded),
  'birth_needed' || 'birth_invalid' => const SaveRefused(Refusal.birthInvalid),
  'exact_birth_needed' => const SaveRefused(Refusal.exactBirthNeeded),
  'confirm_age' => const SaveRefused(Refusal.confirmAge),
  'birth_date_locked' => const SaveRefused(Refusal.birthLocked),
  // anything else (signed out, not reachable, the function not there yet) is a "try again"
  _ => const SaveFailed(SendCopy.unreachable),
};

final basicsSaverProvider = Provider<BasicsSaver>((ref) => SupabaseBasicsSaver(ref.read(supabaseProvider)));
