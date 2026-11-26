import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A page that is at least [minHeight] tall: [top] from the top, [bottom] pinned to the bottom, at least [minGap]
/// apart (kp.css `.grow{flex:1 1 auto;min-height:16px}`). Taller content just makes the page taller, so it can sit in
/// a scroll view and scroll at large text (GI-60) or behind the keyboard (GI-63).
class FillColumn extends MultiChildRenderObjectWidget {
  FillColumn({super.key, required this.minHeight, required Widget top, required Widget bottom, this.minGap = 16})
    : super(children: [top, bottom]);

  final double minHeight;
  final double minGap;

  @override
  RenderFillColumn createRenderObject(BuildContext context) => RenderFillColumn(minHeight: minHeight, minGap: minGap);

  @override
  void updateRenderObject(BuildContext context, RenderFillColumn renderObject) {
    renderObject
      ..minHeight = minHeight
      ..minGap = minGap;
  }
}

class _FillParentData extends ContainerBoxParentData<RenderBox> {}

class RenderFillColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FillParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FillParentData> {
  RenderFillColumn({required this._minHeight, required this._minGap});

  double _minHeight;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  double _minGap;
  set minGap(double v) {
    if (v == _minGap) return;
    _minGap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillParentData) child.parentData = _FillParentData();
  }

  RenderBox get _top => firstChild!;
  RenderBox get _bottom => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_top.getMinIntrinsicWidth(double.infinity), _bottom.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(_top.getMaxIntrinsicWidth(double.infinity), _bottom.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(_minHeight, _top.getMinIntrinsicHeight(width) + _minGap + _bottom.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final child = BoxConstraints.tightFor(width: width);
    _top.layout(child, parentUsesSize: true);
    _bottom.layout(child, parentUsesSize: true);
    final height = math.max(_minHeight, _top.size.height + _minGap + _bottom.size.height);
    size = constraints.constrain(Size(width, height));
    (_top.parentData! as _FillParentData).offset = Offset.zero;
    (_bottom.parentData! as _FillParentData).offset = Offset(0, size.height - _bottom.size.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
