import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/launch/decide_launch.dart';
import 'package:apnedoctors/features/launch/launch_state.dart';

// 10:00 IST on a weekday, from the server's clock.
final noon = DateTime.utc(2026, 11, 24, 4, 30);
final nightUtc = DateTime.utc(2026, 11, 24, 17, 30); // 23:00 IST

const priya = RememberedAccount(firstName: 'Priya', method: SignInMethod.phone, masked: '+91 98•••••210');
const done = LaunchProfile(firstName: 'Priya', onboardingStep: OnboardingStep.done, firstHomeSeen: true);

LaunchState st({
  DateTime? now,
  AppVersion appVersion = const AppVersion(1, 2, 0),
  AppVersion? minVersion,
  bool openedBefore = true,
  RememberedAccount? remembered,
  DateTime? deviceLock,
  DateTime? lastWakeAt,
  bool proIntent = false,
  SessionStatus session = SessionStatus.valid,
  String? userId = 'me',
  LaunchProfile? profile = done,
  bool hasCachedToday = true,
  LaunchLink? link,
}) => LaunchState(
  now: now ?? noon,
  appVersion: appVersion,
  minVersion: minVersion,
  openedBefore: openedBefore,
  remembered: remembered,
  deviceUnder13LockUntil: deviceLock,
  lastWakeAt: lastWakeAt ?? (now ?? noon).subtract(const Duration(minutes: 20)),
  proIntent: proIntent,
  session: session,
  sessionUserId: session == SessionStatus.none ? null : userId,
  profile: session == SessionStatus.none ? null : profile,
  hasCachedToday: hasCachedToday,
  link: link,
);

typedef Row = (String id, String situation, LaunchState state, bool Function(LaunchRoute) expect);

void main() {
  final rows = <Row>[
    (
      'GI-01',
      'never opened on this device',
      st(openedBefore: false, session: SessionStatus.none),
      (r) => r is FullOpening,
    ),
    (
      'GI-02',
      'opened before, signed out, remembered',
      st(remembered: priya, session: SessionStatus.none),
      (r) => r is WelcomeBack && r.account.firstName == 'Priya' && !r.signedOutForSafety,
    ),
    (
      'GI-03',
      'opened before, signed out, nothing remembered',
      st(session: SessionStatus.none),
      (r) => r is WelcomeAgain && !r.signedOutForSafety,
    ),
    ('GI-04', 'signed in, complete, back within 3 h', st(), (r) => r is Today && !r.greeting && !r.night && !r.offline),
    (
      'GI-04',
      'signed in, 3 h or more away: greeting',
      st(lastWakeAt: noon.subtract(const Duration(hours: 3))),
      (r) => r is Today && r.greeting,
    ),
    ('GI-04', 'signed in at 23:00 IST: quieter wake', st(now: nightUtc), (r) => r is Today && r.night),
    (
      'GI-04',
      'teen with a parent\'s yes',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.done,
          teen: true,
          parentConsent: ParentConsent.granted,
          firstHomeSeen: true,
        ),
      ),
      (r) => r is Today,
    ),
    (
      'G17',
      'onboarding just finished: First-time home, not Today',
      st(profile: const LaunchProfile(onboardingStep: OnboardingStep.done)),
      (r) => r is FirstTimeHome,
    ),
    (
      'GI-05',
      'killed mid-onboarding at Health',
      st(profile: const LaunchProfile(onboardingStep: OnboardingStep.health)),
      (r) => r is ResumeOnboarding && r.step == OnboardingStep.health,
    ),
    (
      'GI-05',
      'signed in, no profile answer yet',
      st(profile: const LaunchProfile()),
      (r) => r is ResumeOnboarding && r.step == OnboardingStep.basics,
    ),
    (
      'GI-05',
      'teen who hasn\'t asked a parent yet',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.parent,
          teen: true,
          parentConsent: ParentConsent.needed,
        ),
      ),
      (r) => r is ResumeOnboarding && r.step == OnboardingStep.parent,
    ),
    (
      'GI-06',
      'teen waiting for a parent',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.parent,
          teen: true,
          parentConsent: ParentConsent.pending,
        ),
      ),
      (r) => r is WaitingForParent,
    ),
    (
      'GI-07',
      'parent said no',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.parent,
          teen: true,
          parentConsent: ParentConsent.declined,
        ),
      ),
      (r) => r is ParentConsentFailed && r.why == ParentConsent.declined,
    ),
    (
      'GI-07',
      'parent link expired',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.parent,
          teen: true,
          parentConsent: ParentConsent.expired,
        ),
      ),
      (r) => r is ParentConsentFailed && r.why == ParentConsent.expired,
    ),
    for (final status in [ProStatus.submitted, ProStatus.checking, ProStatus.needsChanges, ProStatus.rejected])
      (
        'GI-08',
        'pro application ${status.name}',
        st(
          proIntent: true,
          profile: LaunchProfile(
            onboardingStep: OnboardingStep.done,
            firstHomeSeen: true,
            proApplication: ProApplicationState(kind: 'doctor', status: status),
          ),
        ),
        (r) => r is ProStatusScreen && r.application.status == status,
      ),
    (
      'GI-08',
      'chose "use as a patient" meanwhile: Today, not pro status',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.done,
          firstHomeSeen: true,
          proApplication: ProApplicationState(kind: 'doctor', status: ProStatus.checking),
        ),
      ),
      (r) => r is Today,
    ),
    (
      'GI-09',
      'approved pro, last mode pro',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.done,
          firstHomeSeen: true,
          lastModePro: true,
          roles: ['doctor'],
        ),
      ),
      (r) => r is ProHome,
    ),
    (
      'GI-09',
      'approved pro, last mode patient',
      st(
        profile: const LaunchProfile(onboardingStep: OnboardingStep.done, firstHomeSeen: true, roles: ['doctor']),
      ),
      (r) => r is Today,
    ),
    (
      'GI-10',
      'stored session refused by the server',
      st(remembered: priya, session: SessionStatus.refreshFailed),
      (r) => r is WelcomeBack && r.signedOutForSafety,
    ),
    (
      'GI-10',
      'refused session, nothing remembered',
      st(session: SessionStatus.refreshFailed),
      (r) => r is WelcomeAgain && r.signedOutForSafety,
    ),
    (
      'GI-11',
      'offline with a session and saved Today',
      st(session: SessionStatus.offline),
      (r) => r is Today && r.offline,
    ),
    (
      'GI-11',
      'offline with a session, nothing saved',
      st(session: SessionStatus.offline, profile: null),
      (r) => r is Offline,
    ),
    (
      'GI-11',
      'offline, profile saved but Today never cached',
      st(session: SessionStatus.offline, hasCachedToday: false),
      (r) => r is Offline,
    ),
    (
      'GI-12',
      'offline, signed out: the usual doors',
      st(remembered: priya, session: SessionStatus.none),
      (r) => r is WelcomeBack,
    ),
    (
      'GI-13',
      'account set to be deleted',
      st(
        profile: LaunchProfile(
          onboardingStep: OnboardingStep.done,
          accountStatus: AccountStatus.deletionScheduled,
          deletionScheduledFor: DateTime.utc(2026, 12, 20),
        ),
      ),
      (r) => r is DeletionScheduled && r.on == DateTime.utc(2026, 12, 20),
    ),
    (
      'GI-14',
      'account on hold',
      st(
        profile: const LaunchProfile(
          onboardingStep: OnboardingStep.done,
          accountStatus: AccountStatus.suspended,
          suspendedReason: 'Reported for abuse',
        ),
      ),
      (r) => r is AccountOnHold && r.reason == 'Reported for abuse',
    ),
    ('GI-15', 'app below the minimum version', st(minVersion: const AppVersion(1, 3, 0)), (r) => r is UpdateNeeded),
    (
      'GI-15',
      'checked before everything, even a never-opened device',
      st(
        minVersion: const AppVersion(2, 0, 0),
        openedBefore: false,
        session: SessionStatus.none,
        deviceLock: noon.add(const Duration(days: 3)),
      ),
      (r) => r is UpdateNeeded,
    ),
    ('GI-15', 'same version is fine', st(minVersion: const AppVersion(1, 2, 0)), (r) => r is Today),
    (
      'GI-16',
      'under-13 lock on this device',
      st(deviceLock: noon.add(const Duration(days: 6)), session: SessionStatus.none),
      (r) => r is SeeYouAt13,
    ),
    (
      'GI-16',
      'device lock passed',
      st(deviceLock: noon.subtract(const Duration(minutes: 1)), session: SessionStatus.none),
      (r) => r is WelcomeAgain,
    ),
    (
      'GI-16',
      'account blocked for a day',
      st(profile: LaunchProfile(blockedUntil: noon.add(const Duration(hours: 20)))),
      (r) => r is SeeYouAt13,
    ),
    (
      'GI-17',
      'deep link while signed out: sign in first, keep the link',
      st(remembered: priya, session: SessionStatus.none, link: const TargetLink('/records/abc')),
      (r) => r is WelcomeBack && r.pendingLink?.location == '/records/abc',
    ),
    (
      'GI-17',
      'deep link on a never-opened device',
      st(openedBefore: false, session: SessionStatus.none, link: const TargetLink('/x')),
      (r) => r is FullOpening && r.pendingLink?.location == '/x',
    ),
    (
      'GI-17',
      'signed in with a link for me: the link, not Today',
      st(link: const TargetLink('/records/abc', forUserId: 'me')),
      (r) => r is LinkTarget,
    ),
    (
      'GI-18',
      'link meant for another account',
      st(link: const TargetLink('/ghar/invite', forUserId: 'someone-else')),
      (r) => r is SwitchAccountPrompt,
    ),
    (
      'GI-19',
      'hospital QR, signed out',
      st(openedBefore: false, session: SessionStatus.none, link: const HospitalQrLink('civil-ahmedabad')),
      (r) => r is HospitalLanding && !r.signedIn && r.hospital == 'civil-ahmedabad',
    ),
    (
      'GI-19',
      'hospital QR, signed in mid-onboarding: the hospital first',
      st(
        profile: const LaunchProfile(onboardingStep: OnboardingStep.health),
        link: const HospitalQrLink('civil-ahmedabad'),
      ),
      (r) => r is HospitalLanding && r.signedIn,
    ),
    (
      'order',
      'account on hold beats unfinished onboarding',
      st(
        profile: const LaunchProfile(onboardingStep: OnboardingStep.basics, accountStatus: AccountStatus.suspended),
      ),
      (r) => r is AccountOnHold,
    ),
    (
      'order',
      'account blocked beats a hospital QR',
      st(
        profile: LaunchProfile(blockedUntil: noon.add(const Duration(hours: 1))),
        link: const HospitalQrLink('x'),
      ),
      (r) => r is SeeYouAt13,
    ),
  ];

  group('decideLaunch', () {
    for (final (id, situation, state, expectRoute) in rows) {
      test('$id: $situation', () {
        final route = decideLaunch(state);
        expect(expectRoute(route), isTrue, reason: 'got ${route.runtimeType}');
      });
    }

    test('every GI-01 to GI-19 row is covered', () {
      final ids = rows.map((r) => r.$1).toSet();
      for (var i = 1; i <= 19; i++) {
        expect(ids, contains('GI-${i.toString().padLeft(2, '0')}'));
      }
    });
  });

  group('reading the server', () {
    test('my_launch_state() maps onto the router\'s profile', () {
      final p = LaunchProfile.fromJson({
        'first_name': 'Priya',
        'onboarding_step': 'data_consent',
        'age_band': '13-17',
        'parent_consent': 'granted',
        'account_status': 'deletion_scheduled',
        'deletion_scheduled_for': '2026-12-20T00:00:00+00:00',
        'suspended_reason': null,
        'blocked_until': null,
        'first_home_seen': false,
        'last_mode': 'pro',
        'roles': ['doctor'],
        'pro_application': {
          'id': 'x',
          'kind': 'doctor',
          'status': 'needs_changes',
          'reason': 'Council',
          'fix_fields': ['council'],
        },
      });
      expect(p.onboardingStep, OnboardingStep.dataConsent);
      expect(p.teen, isTrue);
      expect(p.parentConsent, ParentConsent.granted);
      expect(p.accountStatus, AccountStatus.deletionScheduled);
      expect(p.deletionScheduledFor, DateTime.utc(2026, 12, 20));
      expect(p.lastModePro, isTrue);
      expect(p.roles, ['doctor']);
      expect(p.proApplication!.status, ProStatus.needsChanges);
      expect(p.proApplication!.fixFields, ['council']);
    });

    test('versions compare numerically', () {
      expect(AppVersion.tryParse('1.10.0')! < AppVersion.tryParse('1.9.9')!, isFalse);
      expect(AppVersion.tryParse('0.1.0+1'), const AppVersion(0, 1, 0));
      expect(AppVersion.tryParse('banana'), isNull);
    });
  });
}
