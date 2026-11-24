import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether this device has opened ApneDoctors before.
abstract class LaunchStore {
  bool get openedBefore;

  /// Marked as soon as the opening starts, so an app killed mid-opening never replays it in full
  /// (EC-LAUNCH-04).
  Future<void> markOpened();
}

class PrefsLaunchStore implements LaunchStore {
  PrefsLaunchStore(this._prefs);
  final SharedPreferences _prefs;

  static const key = 'apnedoctors.opened_before';

  @override
  bool get openedBefore => _prefs.getBool(key) ?? false;

  @override
  Future<void> markOpened() => _prefs.setBool(key, true);
}

class MemoryLaunchStore implements LaunchStore {
  MemoryLaunchStore({this.openedBefore = false});

  @override
  bool openedBefore;

  @override
  Future<void> markOpened() async => openedBefore = true;
}

final launchStoreProvider = Provider<LaunchStore>((ref) => throw UnimplementedError('override in main'));

/// Which opening this launch shows. Decided once per cold start, before the store is updated.
enum LaunchKind { firstOpen, returning }

final launchKindProvider = Provider<LaunchKind>((ref) => throw UnimplementedError('override in main'));
