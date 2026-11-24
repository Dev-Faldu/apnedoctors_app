import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/motion/keyframes.dart';

void main() {
  group('Keyframes', () {
    final k = Keyframes(
      dim: 1,
      offsets: const [0, .5, 1],
      values: const [0, 10, 10],
      curves: const [Cubic(.42, 0, 1, 1), null, null],
    );

    test('holds the first and last values outside the track', () {
      expect(k.at(-1), 0);
      expect(k.at(2), 10);
    });

    test('a segment uses its start keyframe curve, else the animation curve', () {
      // ease-in at half way through the first segment is well below linear
      expect(k.at(.25), closeTo(10 * const Cubic(.42, 0, 1, 1).transform(.5), 1e-9));
      final linearFallback = Keyframes(
        dim: 1,
        offsets: const [0, 1],
        values: const [0, 10],
        curves: const [null, null],
      );
      expect(linearFallback.at(.3), closeTo(3, 1e-9));
      expect(linearFallback.at(.3, 0, cssEaseOut), closeTo(10 * cssEaseOut.transform(.3), 1e-9));
    });

    test('withValues replaces whole keyframes', () {
      final r = k.withValues({
        0: [5],
      });
      expect(r.at(0), 5);
      expect(k.at(0), 0, reason: 'original untouched');
    });

    test('multi-dimensional tracks read each number', () {
      final m = Keyframes(dim: 2, offsets: const [0, 1], values: const [0, 100, 10, 200], curves: const [null, null]);
      expect(m.at(.5, 0), 5);
      expect(m.at(.5, 1), 150);
    });
  });

  group('CssAnim', () {
    test('fill modes behave like CSS', () {
      const both = CssAnim(1, delay: 1);
      expect(both.progress(0), 0);
      expect(both.progress(3), 1);
      const fwd = CssAnim(1, delay: 1, fill: Fill.forwards);
      expect(fwd.progress(0), isNull);
      expect(fwd.progress(3), 1);
      const none = CssAnim(1, delay: 1, fill: Fill.none);
      expect(none.progress(0), isNull);
      expect(none.progress(2.5), isNull);
      expect(none.progress(1.5), .5);
    });

    test('infinite animations loop from their delay', () {
      const loop = CssAnim(2, delay: 1, infinite: true, fill: Fill.none);
      expect(loop.progress(.5), isNull);
      expect(loop.progress(2), .5);
      expect(loop.progress(4), .5);
    });
  });
}
