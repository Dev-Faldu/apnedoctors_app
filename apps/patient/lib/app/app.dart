import 'package:cupertino_ui/cupertino_ui.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;

import '../core/theme/tokens.dart';
import '../features/get_started/get_started_screen.dart';
import '../features/launch/launch_gate.dart';
import '../features/welcome/doorway_hand_off.dart';

/// Routes. Welcome lives under the launch gate; each door opens its own path.
abstract final class Routes {
  static const getStarted = '/get-started';
}

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LaunchGate()),
    GoRoute(path: Routes.getStarted, pageBuilder: getStartedPage),
  ],
);

/// Get started, reached by walking through Welcome's doorway: Welcome grows its doorway past you (its secondary
/// animation), Get started carries the a on and brings its own paper and toran in (its animation). Back reverses it.
Page<void> getStartedPage(BuildContext context, GoRouterState state) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: const Duration(milliseconds: 900),
  reverseTransitionDuration: const Duration(milliseconds: 700),
  child: GetStartedScreen(flightFrom: state.extra is AFlightStart ? state.extra! as AFlightStart : null),
  transitionsBuilder: (context, animation, secondary, child) => child,
);

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
