import 'package:flutter/animation.dart';

/// CSS-style keyframes: values at offsets (0–1), eased per segment.
///
/// A segment uses its start keyframe's curve, or the animation's own timing function when that is
/// null, exactly like `animation-timing-function` inside `@keyframes`. Values are flat lists of
/// [dim] numbers per keyframe.
class Keyframes {
  Keyframes({required this.dim, required this.offsets, required this.values, required this.curves})
    : assert(values.length == offsets.length * dim),
      assert(curves.length == offsets.length);

  /// A single-number track from `(offset, value)` pairs.
  factory Keyframes.of(List<(double, double)> frames, {List<Curve?>? curves}) => Keyframes(
    dim: 1,
    offsets: [for (final f in frames) f.$1],
    values: [for (final f in frames) f.$2],
    curves: curves ?? List<Curve?>.filled(frames.length, null),
  );

  final int dim;
  final List<double> offsets;
  final List<double> values;
  final List<Curve?> curves;

  /// The same track with some keyframe values replaced (`index -> values`).
  Keyframes withValues(Map<int, List<double>> replace) {
    final v = List<double>.of(values);
    replace.forEach((i, vals) {
      for (var d = 0; d < dim; d++) {
        v[i * dim + d] = vals[d];
      }
    });
    return Keyframes(dim: dim, offsets: offsets, values: v, curves: curves);
  }

  /// Value number [d] at progress [p].
  double at(double p, [int d = 0, Curve fallback = Curves.linear]) {
    final n = offsets.length;
    if (p <= offsets.first) return values[d];
    if (p >= offsets.last) return values[(n - 1) * dim + d];
    var i = 0;
    while (i < n - 2 && offsets[i + 1] <= p) {
      i++;
    }
    final o0 = offsets[i], o1 = offsets[i + 1];
    if (o1 <= o0) return values[(i + 1) * dim + d];
    final local = ((p - o0) / (o1 - o0)).clamp(0.0, 1.0);
    final eased = (curves[i] ?? fallback).transform(local);
    final a = values[i * dim + d], b = values[(i + 1) * dim + d];
    return a + (b - a) * eased;
  }
}

enum Fill { none, forwards, backwards, both }

/// One CSS animation: duration, delay, iteration count, fill mode and timing function.
class CssAnim {
  const CssAnim(this.duration, {this.delay = 0, this.infinite = false, this.fill = Fill.both, this.curve = cssEase});

  final double duration;
  final double delay;
  final bool infinite;
  final Fill fill;
  final Curve curve;

  /// Progress through the current iteration at time [t] (s), or null when the animation has no
  /// effect (before its delay without backwards fill, after its end without forwards fill).
  double? progress(double t) {
    final local = t - delay;
    if (local < 0) {
      return (fill == Fill.backwards || fill == Fill.both) ? 0 : null;
    }
    if (infinite) return (local % duration) / duration;
    if (local >= duration) {
      return (fill == Fill.forwards || fill == Fill.both) ? 1 : null;
    }
    return local / duration;
  }

  bool started(double t) => t >= delay;

  /// Two-keyframe `from`/`to` animation with this anim's timing function. Null when not in effect.
  double? lerp(double t, double from, double to) {
    final p = progress(t);
    if (p == null) return null;
    return from + (to - from) * curve.transform(p);
  }

  /// [frames] evaluated at time [t], segments eased with this anim's timing function.
  double? sample(double t, Keyframes frames, [int d = 0]) {
    final p = progress(t);
    if (p == null) return null;
    return frames.at(p, d, curve);
  }
}

// CSS named timing functions.
const cssEase = Cubic(0.25, 0.1, 0.25, 1.0);
const cssEaseIn = Cubic(0.42, 0.0, 1.0, 1.0);
const cssEaseOut = Cubic(0.0, 0.0, 0.58, 1.0);
const cssEaseInOut = Cubic(0.42, 0.0, 0.58, 1.0);
const cssLinear = Curves.linear;
