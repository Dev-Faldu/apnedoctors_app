import 'package:flutter/foundation.dart';

/// Everything the launch router looks at (docs/product/specs/getting-in.md, section 1).
/// Plain data, no Flutter or Supabase types, so `decideLaunch` stays a pure, table-tested function.
@immutable
class LaunchState {
  const LaunchState({
    required this.now,
    this.appVersion = const AppVersion(0, 1, 0),
    this.minVersion,
    this.openedBefore = false,
    this.remembered,
    this.deviceUnder13LockUntil,
    this.lastWakeAt,
    this.proIntent = false,
    this.session = SessionStatus.none,
    this.sessionUserId,
    this.profile,
    this.hasCachedToday = false,
    this.link,
  });

  /// Now, from the server's clock when we have it (GI-54).
  final DateTime now;
  final AppVersion appVersion;
  final AppVersion? minVersion;

  // device flags
  final bool openedBefore;
  final RememberedAccount? remembered;
  final DateTime? deviceUnder13LockUntil;
  final DateTime? lastWakeAt;

  /// The person is part-way through joining as a partner on this device.
  final bool proIntent;

  // session
  final SessionStatus session;
  final String? sessionUserId;

  /// From `public.my_launch_state()`, or the last saved copy when offline. Null: not known.
  final LaunchProfile? profile;

  /// Today has something saved to show offline (GI-11).
  final bool hasCachedToday;

  final LaunchLink? link;
}

enum SessionStatus {
  none,
  valid,

  /// A stored session the server no longer accepts (revoked, expired, account deleted elsewhere).
  refreshFailed,

  /// A stored session, and no network to check it.
  offline,
}

enum SignInMethod { phone, google }

@immutable
class RememberedAccount {
  const RememberedAccount({required this.firstName, required this.method, required this.masked});

  final String firstName;
  final SignInMethod method;

  /// `+91 98•••••210` or `p•••@gmail.com`.
  final String masked;
}

enum OnboardingStep { basics, parent, dataConsent, health, medicines, abha, apps, notifications, done }

enum ParentConsent { notNeeded, needed, pending, granted, declined, expired }

enum AccountStatus { active, deletionScheduled, suspended }

enum ProStatus { draft, submitted, checking, needsChanges, approved, rejected }

@immutable
class ProApplicationState {
  const ProApplicationState({required this.kind, required this.status, this.reason, this.fixFields = const []});

  final String kind;
  final ProStatus status;
  final String? reason;
  final List<String> fixFields;
}

/// The server's view of the person (`public.my_launch_state()`).
@immutable
class LaunchProfile {
  const LaunchProfile({
    this.firstName,
    this.onboardingStep = OnboardingStep.basics,
    this.teen = false,
    this.parentConsent = ParentConsent.notNeeded,
    this.accountStatus = AccountStatus.active,
    this.deletionScheduledFor,
    this.suspendedReason,
    this.blockedUntil,
    this.firstHomeSeen = false,
    this.lastModePro = false,
    this.roles = const [],
    this.proApplication,
  });

  final String? firstName;
  final OnboardingStep onboardingStep;
  final bool teen;
  final ParentConsent parentConsent;
  final AccountStatus accountStatus;
  final DateTime? deletionScheduledFor;
  final String? suspendedReason;
  final DateTime? blockedUntil;
  final bool firstHomeSeen;
  final bool lastModePro;
  final List<String> roles;
  final ProApplicationState? proApplication;

  /// Reads `public.my_launch_state()`.
  factory LaunchProfile.fromJson(Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      final name = _camel(raw as String?);
      return values.firstWhere((v) => v.name == name, orElse: () => fallback);
    }

    DateTime? time(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
    final app = j['pro_application'];
    return LaunchProfile(
      firstName: j['first_name'] as String?,
      onboardingStep: pick(OnboardingStep.values, j['onboarding_step'], OnboardingStep.basics),
      teen: j['age_band'] == '13-17',
      parentConsent: pick(ParentConsent.values, j['parent_consent'], ParentConsent.notNeeded),
      accountStatus: pick(AccountStatus.values, j['account_status'], AccountStatus.active),
      deletionScheduledFor: time(j['deletion_scheduled_for']),
      suspendedReason: j['suspended_reason'] as String?,
      blockedUntil: time(j['blocked_until']),
      firstHomeSeen: j['first_home_seen'] == true,
      lastModePro: j['last_mode'] == 'pro',
      roles: [for (final r in (j['roles'] as List? ?? const [])) r as String],
      proApplication: app is Map
          ? ProApplicationState(
              kind: app['kind'] as String,
              status: pick(ProStatus.values, app['status'], ProStatus.draft),
              reason: app['reason'] as String?,
              fixFields: [for (final f in (app['fix_fields'] as List? ?? const [])) f as String],
            )
          : null,
    );
  }

  static String? _camel(String? snake) {
    if (snake == null) return null;
    final parts = snake.split('_');
    return parts.first + parts.skip(1).map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();
  }
}

/// How the app was opened, when it wasn't from its icon.
sealed class LaunchLink {
  const LaunchLink();
}

/// A hospital's QR (GI-19).
class HospitalQrLink extends LaunchLink {
  const HospitalQrLink(this.hospital);
  final String hospital;
}

/// A deep link or a notification (GI-17, GI-18). [forUserId] is set when it is meant for one account.
class TargetLink extends LaunchLink {
  const TargetLink(this.location, {this.forUserId});
  final String location;
  final String? forUserId;
}

@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major, minor, patch;

  static AppVersion? tryParse(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(s.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  int compareTo(AppVersion o) =>
      major != o.major ? major - o.major : (minor != o.minor ? minor - o.minor : patch - o.patch);

  bool operator <(AppVersion o) => compareTo(o) < 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
