import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/brand/living_a.dart';
import '../../core/motion/keyframes.dart';

/// The moods of the living "a" (docs/product/memory.md). Each is tied to a real moment.
enum AMood {
  /// Idle: breathes, blinks now and then, glances around.
  breathing,

  /// Someone is typing: the eyes follow the caret ([LivingA.lookAt]).
  listening,

  /// Pleased to see you, or something went right: happy eyes, a small hop, pink cheeks.
  happy,

  /// Opening its eyes slowly, one blink, then a smile (Welcome back, quick wake).
  waking,

  /// Eyes closed, slow breathing.
  asleep,

  /// You're in: happy eyes, cheeks, a bounce and a little sway.
  celebrating,

  /// Something isn't right: smaller eyes looking down, a tiny tremble.
  worried,
}

/// The living "a", drawn with CustomPainter. Decorative for screen readers unless [semanticLabel] is given (GI-61).
/// With reduced motion each mood holds one still pose (GI-62).
class LivingA extends StatefulWidget {
  const LivingA({super.key, this.mood = AMood.breathing, this.size = 72, this.lookAt, this.semanticLabel});

  final AMood mood;

  /// Width of the a's bounds.
  final double size;

  /// Listening: where the caret is, 0 (left) to 1 (right).
  final double? lookAt;

  final String? semanticLabel;

  @override
  State<LivingA> createState() => _LivingAState();
}

class _LivingAState extends State<LivingA> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);

  /// Time the current mood began.
  double _moodStart = 0;
  AFace? _from;
  _Pose? _fromPose;

  // smoothed gaze for listening (a soft spring, never a jump)
  double _gaze = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reduced motion: one still pose per mood, and no frames at all (GI-62)
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _ticker.isActive) _ticker.stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
  }

  void _tick(Duration e) {
    final t = e.inMicroseconds / 1e6;
    final target = ((widget.lookAt ?? .5) - .5) * 2 * 6; // ±6 a-units
    final dt = (t - _clock.value).clamp(0.0, .1);
    _gaze += (target - _gaze) * (1 - math.exp(-dt * 10));
    _clock.value = t;
  }

  @override
  void didUpdateWidget(LivingA old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      final t = _clock.value;
      _from = _face(old.mood, t - _moodStart, false);
      _fromPose = _pose(old.mood, t - _moodStart, false);
      _moodStart = t;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ---- the moods ------------------------------------------------------------------------------
  static final _blink = Keyframes.of(const [(0, 1), (.92, 1), (.95, .08), (1, 1)]);
  static final _look = Keyframes.of(const [
    (0, 0),
    (.30, 0),
    (.38, 5),
    (.52, 5),
    (.60, -4),
    (.70, -4),
    (.78, 0),
    (1, 0),
  ]);

  double _blinkAt(double t, {double every = 4.4}) =>
      CssAnim(every, infinite: true, fill: Fill.none, curve: cssEase).sample(t, _blink) ?? 1;

  AFace _face(AMood mood, double t, bool reduced) {
    switch (mood) {
      case AMood.breathing:
        final look = reduced ? 0.0 : CssAnim(7, infinite: true, curve: cssEaseInOut).sample(t, _look)!;
        return AFace(gaze: Offset(look, 0), lid: reduced ? 1 : _blinkAt(t), blushStyle: BlushStyle.cheeks);
      case AMood.listening:
        return AFace(
          gaze: Offset(reduced ? 0 : _gaze, -1),
          lid: reduced ? 1 : _blinkAt(t, every: 5.2),
          blushStyle: BlushStyle.cheeks,
        );
      case AMood.happy:
        return const AFace(open: 0, happy: 1, blushStyle: BlushStyle.cheeks, happyLift: 15);
      case AMood.waking:
        if (reduced) return const AFace(blushStyle: BlushStyle.cheeks);
        // closed → eyes open slowly (0–0.9 s) → one blink (1.2 s) → a smile (1.6–2.4 s) → awake
        if (t < .9) {
          final e = cssEaseInOut.transform((t / .9).clamp(0, 1));
          return AFace(open: e, asleep: 1 - e, lid: .1 + .9 * e, blushStyle: BlushStyle.cheeks);
        }
        if (t < 1.4) {
          final b = CssAnim(
            .3,
            delay: 1.1,
            curve: cssEaseInOut,
          ).sample(t, Keyframes.of(const [(0, 1), (.5, .1), (1, 1)]))!;
          return AFace(lid: b, blushStyle: BlushStyle.cheeks);
        }
        if (t < 2.4) {
          final h = t < 1.6 ? (t - 1.4) / .2 : (t > 2.2 ? (2.4 - t) / .2 : 1.0);
          return AFace(open: 1 - h, happy: h, blushStyle: BlushStyle.cheeks, happyLift: 15);
        }
        return AFace(lid: _blinkAt(t - 2.4), blushStyle: BlushStyle.cheeks);
      case AMood.asleep:
        return const AFace(open: 0, asleep: 1, blushStyle: BlushStyle.cheeks);
      case AMood.celebrating:
        return const AFace(open: 0, happy: 1, blushStyle: BlushStyle.cheeks, happyLift: 15);
      case AMood.worried:
        return AFace(
          gaze: const Offset(-3, 3),
          lid: reduced ? .8 : .8 * _blinkAt(t, every: 3.6),
          eyeScale: .78,
          blushStyle: BlushStyle.cheeks,
        );
    }
  }

  _Pose _pose(AMood mood, double t, bool reduced) {
    if (reduced) return const _Pose();
    double breathe(double period, double amount) => 1 + amount * (.5 - .5 * math.cos(2 * math.pi * t / period));
    switch (mood) {
      case AMood.breathing:
      case AMood.listening:
        final s = breathe(4, .035);
        return _Pose(sx: s, sy: s, tilt: mood == AMood.listening ? -4 * math.pi / 180 : 0);
      case AMood.asleep:
        final s = breathe(6, .05);
        return _Pose(sx: 1 + (s - 1) * .6, sy: s);
      case AMood.happy:
        // one small hop when the mood arrives (the splash's smile hop), then breathing
        final hop = t < .16
            ? -9 * cssEaseOut.transform(t / .16)
            : (t < .4 ? -9 * (1 - cssEaseIn.transform((t - .16) / .24)) : 0.0);
        final s = breathe(4, .035);
        return _Pose(ty: hop, sx: s, sy: s);
      case AMood.waking:
        final s = breathe(4, .035);
        return _Pose(sx: s, sy: s);
      case AMood.celebrating:
        final phase = (t % .9) / .9;
        final jump = -14 * math.sin(math.pi * phase).abs();
        final squash = phase < .1 || phase > .9 ? 1.05 : 1.0;
        return _Pose(ty: jump, sx: squash, sy: 2 - squash, tilt: 5 * math.sin(2 * math.pi * t / 1.8) * math.pi / 180);
      case AMood.worried:
        return _Pose(tx: .6 * math.sin(2 * math.pi * t * 5), sx: .98, sy: .98);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final s = widget.size / AShape.bounds.width;
    final paint = SizedBox(
      width: widget.size,
      height: AShape.bounds.height * s + 16 * s, // room for a hop
      child: CustomPaint(
        painter: _APainter(
          clock: _clock,
          scale: s,
          build: (t) {
            final local = t - _moodStart;
            var face = _face(widget.mood, local, reduced);
            var pose = _pose(widget.mood, local, reduced);
            // moods cross-fade over 250 ms, never jump
            final from = _from, fromPose = _fromPose;
            if (from != null && fromPose != null && local < .25 && !reduced) {
              final k = cssEaseInOut.transform((local / .25).clamp(0, 1));
              face = _mix(from, face, k);
              pose = _Pose.lerp(fromPose, pose, k);
            }
            return (face, pose);
          },
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null ? ExcludeSemantics(child: paint) : Semantics(label: label, image: true, child: paint);
  }

  static AFace _mix(AFace a, AFace b, double k) {
    double l(double x, double y) => x + (y - x) * k;
    return AFace(
      open: l(a.open, b.open),
      happy: l(a.happy, b.happy),
      asleep: l(a.asleep, b.asleep),
      blush: l(a.blush, b.blush),
      gaze: Offset.lerp(a.gaze, b.gaze, k)!,
      lid: l(a.lid, b.lid),
      blushStyle: b.blushStyle,
      happyLift: l(a.happyLift, b.happyLift),
      eyeScale: l(a.eyeScale, b.eyeScale),
    );
  }
}

class _Pose {
  const _Pose({this.tx = 0, this.ty = 0, this.sx = 1, this.sy = 1, this.tilt = 0});
  final double tx, ty, sx, sy, tilt;

  static _Pose lerp(_Pose a, _Pose b, double k) {
    double l(double x, double y) => x + (y - x) * k;
    return _Pose(tx: l(a.tx, b.tx), ty: l(a.ty, b.ty), sx: l(a.sx, b.sx), sy: l(a.sy, b.sy), tilt: l(a.tilt, b.tilt));
  }
}

class _APainter extends CustomPainter {
  _APainter({required this.clock, required this.scale, required this.build}) : super(repaint: clock);
  final ValueNotifier<double> clock;
  final double scale;
  final (AFace, _Pose) Function(double t) build;

  @override
  void paint(Canvas canvas, Size size) {
    final (face, pose) = build(clock.value);
    canvas.scale(scale);
    // stand on the bottom of the box, leaving room above for a hop
    canvas.translate(-AShape.bounds.left, -AShape.bounds.top + 16);
    // body moments happen around the bottom of the bowl (0, 53), like the splash's pop
    canvas.translate(pose.tx, 53 + pose.ty);
    canvas.rotate(pose.tilt);
    canvas.scale(pose.sx, pose.sy);
    canvas.translate(0, -53);
    paintLivingA(canvas, face);
  }

  @override
  bool shouldRepaint(_APainter old) => true;
}
