import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A code that was sent and not yet entered, kept so closing the app doesn't lose it (GI-29). Lives 10 minutes.
class PendingCode {
  const PendingCode({required this.e164, required this.sentAt, this.sends = 1});
  final String e164;
  final DateTime sentAt;
  final int sends;

  Map<String, Object> toJson() => {'phone': e164, 'sentAt': sentAt.millisecondsSinceEpoch, 'sends': sends};

  static PendingCode? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PendingCode(
        e164: m['phone'] as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int),
        sends: (m['sends'] as int?) ?? 1,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Remembers what this device needs at launch: whether ApneDoctors has opened before, and a code waiting to be typed.
abstract class LaunchStore {
  bool get openedBefore;

  /// Marked once Welcome is shown (GI-01): someone who closes the app mid-opening sees it again.
  Future<void> markOpened();

  PendingCode? get pendingCode;

  /// Null forgets it (verified, or the number changed).
  Future<void> setPendingCode(PendingCode? code);

  /// About you, part-way through (JSON, see `BasicsDraft`): what was typed and where they were, so closing the app
  /// loses nothing (GI-05, GI-64). Null once it is saved.
  String? get basicsDraft;
  Future<void> setBasicsDraft(String? json);

  /// Under 13 on this phone: See you at 13 at every launch until then (GI-16, GI-41).
  DateTime? get under13Until;
  Future<void> setUnder13Until(DateTime? until);
}

class PrefsLaunchStore implements LaunchStore {
  PrefsLaunchStore(this._prefs);
  final SharedPreferences _prefs;

  static const key = 'apnedoctors.opened_before';

  @override
  bool get openedBefore => _prefs.getBool(key) ?? false;

  @override
  Future<void> markOpened() => _prefs.setBool(key, true);

  static const pendingKey = 'apnedoctors.pending_code';

  @override
  PendingCode? get pendingCode => PendingCode.fromJson(_prefs.getString(pendingKey));

  @override
  Future<void> setPendingCode(PendingCode? code) =>
      code == null ? _prefs.remove(pendingKey) : _prefs.setString(pendingKey, jsonEncode(code.toJson()));

  static const draftKey = 'apnedoctors.basics_draft';

  @override
  String? get basicsDraft => _prefs.getString(draftKey);

  @override
  Future<void> setBasicsDraft(String? json) =>
      json == null ? _prefs.remove(draftKey) : _prefs.setString(draftKey, json);

  static const under13Key = 'apnedoctors.under13_until';

  @override
  DateTime? get under13Until {
    final ms = _prefs.getInt(under13Key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setUnder13Until(DateTime? until) =>
      until == null ? _prefs.remove(under13Key) : _prefs.setInt(under13Key, until.millisecondsSinceEpoch);
}

class MemoryLaunchStore implements LaunchStore {
  MemoryLaunchStore({this.openedBefore = false});

  @override
  bool openedBefore;

  @override
  Future<void> markOpened() async => openedBefore = true;

  @override
  PendingCode? pendingCode;

  @override
  Future<void> setPendingCode(PendingCode? code) async => pendingCode = code;

  @override
  String? basicsDraft;

  @override
  Future<void> setBasicsDraft(String? json) async => basicsDraft = json;

  @override
  DateTime? under13Until;

  @override
  Future<void> setUnder13Until(DateTime? until) async => under13Until = until;
}

/// Overridden in main with the phone's own storage; on its own (tests, tools) it remembers in memory.
final launchStoreProvider = Provider<LaunchStore>((ref) => MemoryLaunchStore());

/// Which opening this launch shows. Decided once per cold start, before the store is updated.
enum LaunchKind { firstOpen, returning }

final launchKindProvider = Provider<LaunchKind>((ref) => throw UnimplementedError('override in main'));
