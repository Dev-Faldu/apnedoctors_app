import 'dart:ui';

/// Builds a [Path] from flat ops written by tool/gen_opening_spec.py:
/// 0 M x y · 1 L x y · 2 Q x1 y1 x y · 3 C x1 y1 x2 y2 x y · 4 Z.
Path pathFromOps(List<double> ops) {
  final p = Path();
  var i = 0;
  while (i < ops.length) {
    switch (ops[i].toInt()) {
      case 0:
        p.moveTo(ops[i + 1], ops[i + 2]);
        i += 3;
      case 1:
        p.lineTo(ops[i + 1], ops[i + 2]);
        i += 3;
      case 2:
        p.quadraticBezierTo(ops[i + 1], ops[i + 2], ops[i + 3], ops[i + 4]);
        i += 5;
      case 3:
        p.cubicTo(ops[i + 1], ops[i + 2], ops[i + 3], ops[i + 4], ops[i + 5], ops[i + 6]);
        i += 7;
      case 4:
        p.close();
        i += 1;
      default:
        throw StateError('bad path op ${ops[i]}');
    }
  }
  return p;
}

/// A path with its contours measured once, for "drawn by hand" reveals and dotted strokes.
class MeasuredPath {
  MeasuredPath(this.path) : _metrics = path.computeMetrics().toList() {
    total = _metrics.fold(0.0, (s, m) => s + m.length);
  }

  final Path path;
  final List<PathMetric> _metrics;
  late final double total;

  /// The path drawn by hand up to [fraction], like SVG `pathLength="1"` with
  /// `stroke-dasharray: 1 1` and `stroke-dashoffset: 1 - fraction` in Chrome: the dash spans
  /// fraction x the total length, and the pattern restarts on every contour (Skia dashing), so a
  /// letter's outer and inner outlines are drawn at the same time.
  Path head(double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    final len = total * fraction;
    for (final m in _metrics) {
      out.addPath(m.extractPath(0, len < m.length ? len : m.length), Offset.zero);
    }
    return out;
  }

  /// The first [length] units of the path (SVG `stroke-dasharray: N` revealed by `stroke-dashoffset`).
  Path headLength(double length) => head(total <= 0 ? 0 : length / total);

  /// Points every [spacing] along the path, shifted by [offset] (SVG `stroke-dasharray: 0 spacing`
  /// with `stroke-dashoffset: -offset` and round caps gives a dot at each of these points).
  Iterable<Offset> dots(double spacing, {double offset = 0}) sync* {
    var start = offset % spacing;
    if (start < 0) start += spacing;
    for (final m in _metrics) {
      for (var s = start; s <= m.length + 1e-6; s += spacing) {
        final tan = m.getTangentForOffset(s.clamp(0, m.length));
        if (tan != null) yield tan.position;
      }
      start = (start - m.length) % spacing;
      if (start < 0) start += spacing;
    }
  }
}
