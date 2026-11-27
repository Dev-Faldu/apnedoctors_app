import 'package:cupertino_ui/cupertino_ui.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/backend.dart';
import '../core/theme/tokens.dart';
import '../features/about_you/about_you_screen.dart';
import '../features/about_you/basics.dart';
import '../features/get_started/code_screen.dart';
import '../features/get_started/code_verifier.dart';
import '../features/get_started/get_started_screen.dart';
import '../features/launch/launch_gate.dart';
import '../features/launch/launch_store.dart';
import '../features/welcome/doorway_hand_off.dart';
import '../shared/indian_phone.dart';

/// Routes. Welcome lives under the launch gate; each door opens its own path.
abstract final class Routes {
  static const getStarted = '/get-started';
  static const code = '/code';
  static const aboutYou = '/about-you';
}

final router = GoRouter(
  redirect: restoreOnLaunch,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LaunchGate()),
    GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
    GoRoute(path: Routes.code, pageBuilder: codePage),
    GoRoute(path: Routes.aboutYou, pageBuilder: aboutYouPage),
  ],
);

bool _restoreChecked = false;

/// Once, at launch, the app goes back to where someone left off:
/// - a code sent in the last 10 minutes and not yet entered: the code screen (GI-29);
/// - signed in with About you not yet saved: About you, with what they had typed (GI-05).
/// An under-13 lock on this phone wins over both (GI-16): the launch gate shows See you at 13.
String? restoreOnLaunch(BuildContext context, GoRouterState state) {
  if (_restoreChecked) return null;
  _restoreChecked = true;
  if (state.matchedLocation != '/') return null;
  final container = ProviderScope.containerOf(context, listen: false);
  final store = container.read(launchStoreProvider);
  final lock = store.under13Until;
  if (lock != null && lock.isAfter(clock.now())) return null;
  if (_pendingArrival(context) != null) return Routes.code;
  if (store.basicsDraft != null && container.read(signedInProvider)) return Routes.aboutYou;
  return null;
}

/// For tests: run the launch restore again.
@visibleForTesting
void resetLaunchRestore() => _restoreChecked = false;

CodeArrival? _pendingArrival(BuildContext context) {
  final pending = ProviderScope.containerOf(context, listen: false).read(launchStoreProvider).pendingCode;
  if (pending == null || clock.now().difference(pending.sentAt) > CodeRules.pendingLife) return null;
  final phone = parseIndianPhone(pending.e164);
  if (phone is! PhoneOk) return null;
  return CodeArrival(phone: phone, sentAt: pending.sentAt, sends: pending.sends);
}

/// Get started, reached by walking through Welcome's doorway: Welcome grows its doorway past you (its secondary
/// animation), Get started carries the a on and brings its own paper and toran in (its animation). Back reverses it.
Page<void> getStartedPage(BuildContext context, GoRouterState state) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: const Duration(milliseconds: 900),
  reverseTransitionDuration: const Duration(milliseconds: 700),
  child: Builder(
    builder: (context) => GetStartedScreen(
      flightFrom: state.extra is AFlightStart ? state.extra! as AFlightStart : null,
      initialPhone: state.extra is String ? state.extra! as String : null,
      openCode: (arrival) => context.push<String>(Routes.code, extra: arrival),
    ),
  ),
  transitionsBuilder: (context, animation, secondary, child) => child,
);

/// The code screen (GS2). From the phone screen the page changes around a still toran and a, and the number flies up
/// (0.7 s; Back 0.56 s). Restored after the app was closed (GI-29), it simply opens.
Page<void> codePage(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  final arrival = extra is CodeArrival ? extra : _pendingArrival(context);
  if (arrival == null) return getStartedPage(context, state);
  final number = arrival.phone.e164;
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 700),
    reverseTransitionDuration: const Duration(milliseconds: 560),
    child: Builder(
      builder: (context) => CodeScreen(
        arrival: arrival,
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.getStarted, extra: number),
        onChange: () => context.canPop() ? context.pop('change') : context.go(Routes.getStarted, extra: number),
        onVerified: (clockAt) {
          // from here on, closing the app comes back to About you (GI-05)
          final store = ProviderScope.containerOf(context, listen: false).read(launchStoreProvider);
          store.setBasicsDraft(store.basicsDraft ?? const BasicsDraft().toJson());
          context.go(Routes.aboutYou, extra: clockAt);
        },
      ),
    ),
    transitionsBuilder: (context, animation, secondary, child) => child,
  );
}

/// About you (GS3). From the code screen the page changes around the still toran and a (0.76 s): the code page steps
/// aside, the a greets you. Signed in, the code screen and the doors before it are gone: there is no going back to them.
Page<void> aboutYouPage(BuildContext context, GoRouterState state) {
  final store = ProviderScope.containerOf(context, listen: false).read(launchStoreProvider);
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 760),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    child: AboutYouScreen(
      clockFrom: state.extra is double ? state.extra! as double : 0,
      draft: BasicsDraft.fromJson(store.basicsDraft),
      // Your data (GS5) or a parent's yes (GS4) comes next, once designed
      onDone: (_) {},
    ),
    transitionsBuilder: (context, animation, secondary, child) => child,
  );
}

class ApneDoctorsApp extends StatelessWidget {
  const ApneDoctorsApp({super.key, this.routerConfig});

  final RouterConfig<Object>? routerConfig;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp.router(
      title: 'ApneDoctors',
      color: AdColors.vermilion,
      debugShowCheckedModeBanner: false,
      routerConfig: routerConfig ?? router,
      textStyle: AdType.lede(),
      // text fields use the platform's own paste and selection menus, which need these words
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => ColoredBox(color: AdColors.paper, child: child),
    );
  }
}
