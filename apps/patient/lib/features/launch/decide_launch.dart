import 'package:flutter/foundation.dart';

import 'launch_state.dart';

/// Where the app opens. Nothing else in the app decides this (docs/product/specs/getting-in.md, section 1).
///
/// Order of checks: update needed → under-13 lock → session → account status → hospital QR → onboarding →
/// teen consent → pro → First-time home → Today.
LaunchRoute decideLaunch(LaunchState s) {
  // GI-15: an app too old to be safe blocks everything, before anything else.
  final min = s.minVersion;
  if (min != null && s.appVersion < min) return const UpdateNeeded();

  // GI-16: under 13, on this device.
  final deviceLock = s.deviceUnder13LockUntil;
  if (deviceLock != null && deviceLock.isAfter(s.now)) return SeeYouAt13(until: deviceLock);

  final link = s.link;
  final pending = link is TargetLink ? link : null;

  switch (s.session) {
    case SessionStatus.none:
      // GI-19: a hospital's QR opens its landing, signed in or not.
      if (link is HospitalQrLink) return HospitalLanding(link.hospital, signedIn: false);
      // GI-01: never opened here.
      if (!s.openedBefore) return FullOpening(pendingLink: pending);
      // GI-02 / GI-03 (and GI-12 offline, GI-17 with a link): the usual signed-out doors.
      final r = s.remembered;
      if (r != null) return WelcomeBack(r, pendingLink: pending);
      return WelcomeAgain(pendingLink: pending);

    case SessionStatus.refreshFailed:
      // GI-10: the dead session is cleared by the caller; say why, calmly.
      final r = s.remembered;
      if (r != null) return WelcomeBack(r, signedOutForSafety: true, pendingLink: pending);
      return WelcomeAgain(signedOutForSafety: true, pendingLink: pending);

    case SessionStatus.offline:
      // GI-11: never sign out for being offline. Decide from what we saved, or say we're offline.
      if (s.profile == null) return const Offline();
      return _signedIn(s, offline: true);

    case SessionStatus.valid:
      return _signedIn(s, offline: false);
  }
}

LaunchRoute _signedIn(LaunchState s, {required bool offline}) {
  final p = s.profile ?? const LaunchProfile();
  final link = s.link;

  // GI-16 again: the account itself is blocked for a day after an under-13 birth date.
  final blocked = p.blockedUntil;
  if (blocked != null && blocked.isAfter(s.now)) return SeeYouAt13(until: blocked);

  // GI-14, GI-13
  if (p.accountStatus == AccountStatus.suspended) return AccountOnHold(p.suspendedReason);
  if (p.accountStatus == AccountStatus.deletionScheduled && p.deletionScheduledFor != null) {
    return DeletionScheduled(p.deletionScheduledFor!);
  }

  // GI-18: a link meant for another account never switches silently.
  if (link is TargetLink && link.forUserId != null && link.forUserId != s.sessionUserId) {
    return SwitchAccountPrompt(link);
  }

  // GI-19
  if (link is HospitalQrLink) return HospitalLanding(link.hospital, signedIn: true);

  // GI-05, GI-06, GI-07: onboarding resumes at its first missing step; a teen's parent sits in the middle of it.
  switch (p.onboardingStep) {
    case OnboardingStep.done:
      break;
    case OnboardingStep.parent:
      switch (p.parentConsent) {
        case ParentConsent.pending:
          return const WaitingForParent();
        case ParentConsent.declined:
        case ParentConsent.expired:
          return ParentConsentFailed(p.parentConsent);
        default:
          return const ResumeOnboarding(OnboardingStep.parent);
      }
    default:
      return ResumeOnboarding(p.onboardingStep);
  }

  // GI-08, GI-09: pro.
  final app = p.proApplication;
  if (s.proIntent && app != null && app.status != ProStatus.approved) return ProStatusScreen(app);
  if (p.lastModePro && p.roles.isNotEmpty) return const ProHome();

  // GI-17: after sign-in, the link instead of Today.
  if (link is TargetLink) return LinkTarget(link);

  // G17: the first time after onboarding.
  if (!p.firstHomeSeen) return const FirstTimeHome();

  // GI-04: Today, with a greeting after 3 h away and a quieter wake at night (22:00–05:00 IST).
  final ist = s.now.toUtc().add(const Duration(hours: 5, minutes: 30));
  final night = ist.hour >= 22 || ist.hour < 5;
  final last = s.lastWakeAt;
  final greet = last == null || s.now.difference(last) >= const Duration(hours: 3);
  if (offline && !s.hasCachedToday) return const Offline();
  return Today(greeting: greet, night: night, offline: offline);
}

/// Where the app opens.
@immutable
sealed class LaunchRoute {
  const LaunchRoute();
}

class UpdateNeeded extends LaunchRoute {
  const UpdateNeeded();
}

class SeeYouAt13 extends LaunchRoute {
  const SeeYouAt13({required this.until});
  final DateTime until;
}

/// GI-01: native splash → full opening → Welcome.
class FullOpening extends LaunchRoute {
  const FullOpening({this.pendingLink});
  final TargetLink? pendingLink;
}

/// GI-03: short brand moment → Welcome with its own entrance.
class WelcomeAgain extends LaunchRoute {
  const WelcomeAgain({this.signedOutForSafety = false, this.pendingLink});
  final bool signedOutForSafety;
  final TargetLink? pendingLink;
}

/// GI-02 / GI-10: short brand moment → Welcome back, {name}.
class WelcomeBack extends LaunchRoute {
  const WelcomeBack(this.account, {this.signedOutForSafety = false, this.pendingLink});
  final RememberedAccount account;
  final bool signedOutForSafety;
  final TargetLink? pendingLink;
}

class Offline extends LaunchRoute {
  const Offline();
}

class AccountOnHold extends LaunchRoute {
  const AccountOnHold(this.reason);
  final String? reason;
}

class DeletionScheduled extends LaunchRoute {
  const DeletionScheduled(this.on);
  final DateTime on;
}

class SwitchAccountPrompt extends LaunchRoute {
  const SwitchAccountPrompt(this.link);
  final TargetLink link;
}

class HospitalLanding extends LaunchRoute {
  const HospitalLanding(this.hospital, {required this.signedIn});
  final String hospital;
  final bool signedIn;
}

class ResumeOnboarding extends LaunchRoute {
  const ResumeOnboarding(this.step);
  final OnboardingStep step;
}

class WaitingForParent extends LaunchRoute {
  const WaitingForParent();
}

class ParentConsentFailed extends LaunchRoute {
  const ParentConsentFailed(this.why);
  final ParentConsent why;
}

class ProStatusScreen extends LaunchRoute {
  const ProStatusScreen(this.application);
  final ProApplicationState application;
}

class ProHome extends LaunchRoute {
  const ProHome();
}

class LinkTarget extends LaunchRoute {
  const LinkTarget(this.link);
  final TargetLink link;
}

class FirstTimeHome extends LaunchRoute {
  const FirstTimeHome();
}

class Today extends LaunchRoute {
  const Today({required this.greeting, required this.night, required this.offline});
  final bool greeting;
  final bool night;
  final bool offline;
}
