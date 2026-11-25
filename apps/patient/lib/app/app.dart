import 'package:cupertino_ui/cupertino_ui.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;

import '../core/theme/tokens.dart';
import '../features/launch/launch_gate.dart';

final router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const LaunchGate())],
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
