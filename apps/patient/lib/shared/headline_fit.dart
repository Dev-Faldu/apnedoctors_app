import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Sizing a headline so it never breaks a word: smaller on narrow phones, and with large text (GI-60) growing only
/// until its longest word fills the line.
abstract final class HeadlineFit {
  /// [style] at a size where [text] fits in [width] (never larger than the style's own).
  static TextStyle fitted(TextStyle style, String text, double width) {
    final w = _width(style, text);
    if (w <= width) return style;
    final k = width / w;
    return style.copyWith(fontSize: style.fontSize! * k, letterSpacing: (style.letterSpacing ?? 0) * k);
  }

  /// How far text in [style] may grow before [word] no longer fits in [width] (at least 1).
  static double grow(TextStyle style, String word, double width) =>
      math.max(1, width / _width(style, word) * .95); // a little margin, so the last letter never wraps alone

  /// The longest line of [text] (lines split at \n), the one that decides how far it can grow.
  static String longestWord(TextStyle style, String text) {
    var best = '';
    var bestW = -1.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final w = _width(style, word);
      if (w > bestW) {
        best = word;
        bestW = w;
      }
    }
    return best;
  }

  static double _width(TextStyle style, String text) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }
}
