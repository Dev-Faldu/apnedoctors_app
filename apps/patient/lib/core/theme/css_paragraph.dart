import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Multi-line text laid out on CSS line boxes.
///
/// Flutter rounds every line's height to a whole pixel (17 px x 1.45 = 24.65 becomes 25), so a
/// paragraph drifts from the browser-made designs and moves everything below it. This keeps
/// Flutter's line breaking and glyphs, but places each line where Chrome does: line height in
/// 1/64 px units, half-leading around the font's rounded ascent and descent.
class CssParagraph extends LeafRenderObjectWidget {
  const CssParagraph(this.text, {super.key, required this.style, this.textAlign = TextAlign.start});

  final String text;

  /// Must set [TextStyle.fontSize] and [TextStyle.height].
  final TextStyle style;
  final TextAlign textAlign;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCssParagraph(text: text, style: style, textAlign: textAlign, textScaler: MediaQuery.textScalerOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderCssParagraph renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..textAlign = textAlign
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

class RenderCssParagraph extends RenderBox {
  RenderCssParagraph({required this._text, required this._style, required this._textAlign, required this._textScaler});

  String _text;
  set text(String v) {
    if (v == _text) return;
    _text = v;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextStyle _style;
  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    markNeedsLayout();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign v) {
    if (v == _textAlign) return;
    _textAlign = v;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler v) {
    if (v == _textScaler) return;
    _textScaler = v;
    markNeedsLayout();
  }

  final _painter = TextPainter(textDirection: TextDirection.ltr);
  List<LineMetrics> _lines = const [];
  double _lineHeight = 0;
  double _baseline = 0;

  static double _layoutUnit(double v) => (v * 64).floorToDouble() / 64;

  void _layoutText(double maxWidth) {
    final size = _textScaler.scale(_style.fontSize!);
    _painter
      ..text = TextSpan(text: _text, style: _style)
      ..textAlign = _textAlign
      ..textScaler = _textScaler
      ..layout(maxWidth: maxWidth);
    _lines = _painter.computeLineMetrics();
    _lineHeight = _layoutUnit(size * _style.height!);
    // Blink rounds the font's ascent and descent, then splits the leading evenly.
    final natural = TextPainter(
      text: TextSpan(text: 'x', style: _style.copyWith(height: null)),
      textDirection: TextDirection.ltr,
      textScaler: _textScaler,
    )..layout();
    final m = natural.computeLineMetrics().first;
    natural.dispose();
    final ascent = m.ascent.roundToDouble(), descent = m.descent.roundToDouble();
    _baseline = _layoutUnit((_lineHeight - (ascent + descent)) / 2) + ascent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText(double.infinity);
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutText(double.infinity);
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(width);
    return _lineHeight * _lines.length;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutText(constraints.maxWidth);
    return constraints.constrain(Size(constraints.maxWidth, _lineHeight * _lines.length));
  }

  @override
  void performLayout() {
    _layoutText(constraints.maxWidth);
    size = constraints.constrain(Size(constraints.maxWidth, _lineHeight * _lines.length));
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final top = offset.dy + i * _lineHeight;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(offset.dx - 8, top, size.width + 16, _lineHeight));
      canvas.translate(0, (top + _baseline) - (offset.dy + line.baseline));
      _painter.paint(canvas, offset);
      canvas.restore();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text
      ..textDirection = TextDirection.ltr;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  /// Number of laid-out lines (for tests).
  int get lineCount => math.max(_lines.length, 0);
}
