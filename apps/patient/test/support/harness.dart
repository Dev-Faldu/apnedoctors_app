import 'package:cupertino_ui/cupertino_ui.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/css_paragraph.dart';
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
          // the app's words for paste/selection menus, and an Overlay for them, like WidgetsApp gives
          child: Localizations(
            locale: const Locale('en'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Overlay.wrap(
                child: DefaultTextStyle(
                  style: AdType.lede(),
                  child: ColoredBox(color: AdColors.paper, child: child),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Finds text drawn on CSS line boxes (`CssParagraph`), which `find.text` can't see.
Finder findParagraph(String text) =>
    find.byWidgetPredicate((w) => w is CssParagraph && w.text == text, description: 'CssParagraph "$text"');
