import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Stops "show me on screen" requests from a text field below it, for screens that decide themselves what scrolls
/// into view when the keyboard opens (the field would otherwise scroll itself straight away, before the screen's
/// layout has settled).
class HoldScroll extends SingleChildRenderObjectWidget {
  const HoldScroll({super.key, required this.hold, required super.child});
  final bool hold;

  @override
  RenderHoldScroll createRenderObject(BuildContext context) => RenderHoldScroll(hold);

  @override
  void updateRenderObject(BuildContext context, RenderHoldScroll renderObject) => renderObject.hold = hold;
}

class RenderHoldScroll extends RenderProxyBox {
  RenderHoldScroll(this.hold);
  bool hold;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!hold) super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
  }
}
