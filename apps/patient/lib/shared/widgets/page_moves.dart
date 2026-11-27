import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The small moves screens make while the page changes around a still toran and "a" (apps/patient/CLAUDE.md,
/// "Moving between screens").

/// Hidden while the next screen is on its way in (it draws the same thing in the same place).
class HideWhile extends StatelessWidget {
  const HideWhile({super.key, required this.away, required this.child});
  final Animation<double> away;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: away,
    child: child,
    builder: (context, child) => Opacity(opacity: away.value > 0 ? 0 : 1, child: child),
  );
}

/// Steps aside to the left (and fades) while the next screen comes in; comes back on Back.
class StepLeft extends StatelessWidget {
  const StepLeft({super.key, required this.away, required this.reduced, required this.child});
  final Animation<double> away;
  final bool reduced;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: away,
    child: child,
    builder: (context, child) {
      final v = away.value;
      if (v == 0) return child!;
      final e = const Interval(0, .4, curve: Curves.easeOutCubic).transform(v);
      return IgnorePointer(
        child: Opacity(
          opacity: 1 - e,
          child: reduced ? child : Transform.translate(offset: Offset(-44 * e, 0), child: child),
        ),
      );
    },
  );
}

/// Slides in from the right (and away to the right on Back) as [route] moves, starting at [start] (0–1).
/// [dx] is the distance; negative slides in from the left.
class SlideIn extends StatelessWidget {
  const SlideIn({super.key, required this.route, required this.start, this.dx = 44, required this.child});
  final Animation<double> route;
  final double start;
  final double dx;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: route,
      child: child,
      builder: (context, child) {
        final v = route.value;
        if (v >= 1) return child!;
        final e = Interval(start, math.min(1, start + .55), curve: Curves.easeOutCubic).transform(v);
        return Opacity(
          opacity: e,
          child: Transform.translate(offset: Offset(dx * (1 - e), 0), child: child),
        );
      },
    );
  }
}
