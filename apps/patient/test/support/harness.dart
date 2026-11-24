import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/tokens.dart';

/// Pins the test view to a phone size (logical px) at [dpr].
void setPhone(WidgetTester tester, Size size, {double dpr = 1}) {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Wraps [child] the way the app does (direction, media query, paper, default text).
Widget phone(Widget child, {List overrides = const [], bool reducedMotion = false, double textScale = 1}) {
  return ProviderScope(
    overrides: [...overrides],
    child: Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: reducedMotion, textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: AdType.lede(),
              child: ColoredBox(color: AdColors.paper, child: child),
            ),
          ),
        );
      },
    ),
  );
}
