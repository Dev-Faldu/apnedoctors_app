import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';

/// The moods of the "a" on Get started (G03 board).
enum GsMood {
  /// Leans in; its eyes move right as digits land.
  listening,

  /// Ten good digits, or the code is on its way: happy eyes, pink cheeks, one hop.
  happy,

  /// The number can't be right, or something went wrong: brows up, small eyes, a little frown, a tremble.
  worried,

  /// Sending: leans back and looks up.
  thinking,
}

/// The living "a" of Get started, drawn from the board's SVG (`svg.amark`, viewBox 168 66 140 124 in a 100 × 88 box).
///
/// [time] is seconds since the screen opened. With [entrance] the "a" glides in from Welcome's doorway on one curve
/// (`gsGlide`, 0.85 s). It breathes from 1 s and blinks from 1.4 s. Mood changes lean and move the eyes smoothly
/// (the board switches them at once); the faces cross-fade in 0.14 s. Reduced motion: still poses only (GI-62).
/// Decorative: screen readers skip it (GI-61).
class GetStartedA extends StatefulWidget {
  const GetStartedA({
    super.key,
    required this.time,
    required this.mood,
    this.digits = 0,
    this.entrance = false,
    this.reduced = false,
  });

  final ValueListenable<double> time;
  final GsMood mood;

  /// Digits typed so far (0–10): where a listening "a" looks.
  final int digits;
  final bool entrance;
  final bool reduced;

  static const size = Size(100, 88);

  @override
  State<GetStartedA> createState() => _GetStartedAState();
}

/// A value that moves to each new target over [duration] seconds, eased.
class _Glide {
  _Glide(this.value, this.duration, this.curve);
  double value;
  final double duration;
  final Curve curve;
  double _from = 0, _to = 0, _at = -1;

  void set(double target, double now, bool instant) {
    final current = at(now);
    if (instant) {
      _from = _to = target;
      _at = -1;
      value = target;
      return;
    }
    if (target == _to && _at >= 0) return;
    _from = current;
    _to = target;
    _at = now;
  }

  double at(double now) {
    if (_at < 0) return value;
    final p = ((now - _at) / duration).clamp(0.0, 1.0);
    value = _from + (_to - _from) * curve.transform(p);
    if (p >= 1) _at = -1;
    return value;
  }
}

class _GetStartedAState extends State<GetStartedA> {
  late final _lean = _Glide(_leanFor(widget.mood), .28, cssEaseInOut);
  late final _eyeX = _Glide(_eyesFor(widget.mood, widget.digits).dx, .18, cssEaseOut);
  late final _eyeY = _Glide(_eyesFor(widget.mood, widget.digits).dy, .18, cssEaseOut);
  late GsMood _face = widget.mood;
  GsMood? _fromFace;
  double _faceAt = -10;
  double _happyAt = -10;

  static double _leanFor(GsMood m) => switch (m) {
    GsMood.listening || GsMood.worried => -7,
    GsMood.thinking => 4,
    GsMood.happy => 0,
  };

  static Offset _eyesFor(GsMood m, int digits) =>
      m == GsMood.thinking ? const Offset(4, -5) : Offset(-6 + math.min(digits, 10) * 1.2, 4);

  @override
  void didUpdateWidget(GetStartedA old) {
    super.didUpdateWidget(old);
    final now = widget.time.value;
    final instant = widget.reduced;
    _lean.set(_leanFor(widget.mood), now, instant);
    final eyes = _eyesFor(widget.mood, widget.digits);
    _eyeX.set(eyes.dx, now, instant);
    _eyeY.set(eyes.dy, now, instant);
    if (widget.mood != old.mood) {
      // listening and thinking share one face (open eyes); only the gaze moves
      final kind = _kind(widget.mood);
      if (kind != _kind(_face)) {
        _fromFace = _face;
        _faceAt = now;
      }
      _face = widget.mood;
      if (widget.mood == GsMood.happy) _happyAt = now;
    }
  }

  static int _kind(GsMood m) => switch (m) {
    GsMood.listening || GsMood.thinking => 0,
    GsMood.happy => 1,
    GsMood.worried => 2,
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: GetStartedA.size,
        child: CustomPaint(painter: _APainter(this, widget.time, widget.reduced)),
      ),
    );
  }
}

class _APainter extends CustomPainter {
  _APainter(this.s, this.time, this.reduced) : super(repaint: time);
  final _GetStartedAState s;
  final ValueListenable<double> time;
  final bool reduced;

  // origins (board units): the fill-box bottom centre of the body, the happy face, the eyes
  static const _body = Offset(239.5, 176);
  static const _hopOrigin = Offset(230, 149.5);

  static final _glideXY = Keyframes(
    dim: 3,
    offsets: const [0, .7, 1],
    values: const [-118, 300, 1.55, 4, -6, .98, 0, 0, 1],
    curves: const [null, null, null],
  );
  static final _glideOpacity = Keyframes.of(const [(0, 0), (.12, 1), (1, 1)]);
  static const _glideCurve = Cubic(.3, 1.15, .4, 1);
  static final _breath = Keyframes(
    dim: 2,
    offsets: const [0, .5, 1],
    values: const [1, 1, 1.035, .975, 1, 1],
    curves: const [null, null, null],
  );
  static final _blink = Keyframes.of(const [(0, 1), (.93, 1), (.96, .08), (1, 1)]);
  static final _hop = Keyframes(
    dim: 3,
    offsets: const [0, .4, .7, 1],
    values: const [0, 1, 1, -10, .96, 1.05, 0, 1.05, .95, 0, 1, 1],
    curves: const [null, null, null, null],
  );
  static const _hopCurve = Cubic(.3, 1.5, .5, 1);
  static final _tremble = Keyframes.of(const [(0, 0), (.25, -1.8), (.75, 1.8), (1, 0)]);

  static final _stroke16 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 16
    ..strokeCap = StrokeCap.round
    ..color = AdColors.vermilion;
  static final _stem = Path()
    ..moveTo(275, 86)
    ..lineTo(275, 156)
    ..quadraticBezierTo(275, 176, 294, 176);

  static Paint _line(double w, double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = AdColors.ink.withValues(alpha: alpha);

  static void _about(Canvas c, Offset o, void Function() f) {
    c.translate(o.dx, o.dy);
    f();
    c.translate(-o.dx, -o.dy);
  }

  double get _t => time.value;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _t;
    // viewBox 168 66 140 124 into 100 × 88, xMidYMid meet
    final k = math.min(size.width / 140, size.height / 124);
    canvas.save();
    canvas.translate((size.width - 140 * k) / 2, (size.height - 124 * k) / 2);
    canvas.scale(k);
    canvas.translate(-168, -66);

    // gsGlide: from Welcome's doorway, one curve, .05 s delay
    var opacity = 1.0;
    if (s.widget.entrance && !reduced) {
      final a = const CssAnim(.85, delay: .05, curve: _glideCurve);
      final p = a.progress(t)!;
      final tx = _glideXY.at(p, 0, a.curve), ty = _glideXY.at(p, 1, a.curve), sc = _glideXY.at(p, 2, a.curve);
      opacity = _glideOpacity.at(p, 0, a.curve);
      _about(canvas, _body, () {
        canvas.translate(tx, ty);
        canvas.scale(sc);
      });
    }
    if (opacity <= 0) {
      canvas.restore();
      return;
    }
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = AdColors.ink.withValues(alpha: opacity));
    }

    // lean, then breathing (from 1 s), both about the body's bottom centre
    final lean = s._lean.at(t) * math.pi / 180;
    _about(canvas, _body, () {
      canvas.rotate(lean);
      if (!reduced) {
        final b = const CssAnim(4.2, delay: 1, infinite: true, fill: Fill.none, curve: cssEaseInOut);
        final p = b.progress(t);
        if (p != null) canvas.scale(_breath.at(p, 0, b.curve), _breath.at(p, 1, b.curve));
      }
    });

    canvas.drawCircle(const Offset(230, 130), 45, _stroke16);
    canvas.drawPath(_stem, _stroke16);

    // faces cross-fade over .14 s
    final from = s._fromFace;
    final fade = reduced || from == null ? 1.0 : ((t - s._faceAt) / .14).clamp(0.0, 1.0);
    if (fade < 1) _face(canvas, from!, t, 1 - fade);
    _face(canvas, s._face, t, fade);

    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  double _blinkAt(double t) {
    if (reduced) return 1;
    final a = const CssAnim(4.6, delay: 1.4, infinite: true, fill: Fill.none, curve: cssEase);
    return a.sample(t, _blink) ?? 1;
  }

  void _eyes(Canvas canvas, Offset c1, Offset c2, double r, double t, double alpha) {
    final centre = Offset((c1.dx + c2.dx) / 2, c1.dy);
    canvas.save();
    _about(canvas, centre, () => canvas.scale(1, _blinkAt(t)));
    final p = Paint()..color = AdColors.ink.withValues(alpha: alpha);
    canvas.drawCircle(c1, r, p);
    canvas.drawCircle(c2, r, p);
    canvas.restore();
  }

  void _face(Canvas canvas, GsMood mood, double t, double alpha) {
    if (alpha <= 0) return;
    switch (mood) {
      case GsMood.listening:
      case GsMood.thinking:
        canvas.save();
        canvas.translate(s._eyeX.at(t), s._eyeY.at(t));
        _eyes(canvas, const Offset(214, 124), const Offset(246, 124), 8, t, alpha);
        canvas.restore();
      case GsMood.happy:
        canvas.save();
        if (!reduced) {
          final a = CssAnim(.7, delay: s._happyAt, fill: Fill.none, curve: _hopCurve);
          final p = a.progress(t);
          if (p != null) {
            _about(canvas, _hopOrigin, () {
              canvas.translate(0, _hop.at(p, 0, a.curve));
              canvas.scale(_hop.at(p, 1, a.curve), _hop.at(p, 2, a.curve));
            });
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(205, 128)
            ..quadraticBezierTo(214, 116, 223, 128)
            ..moveTo(237, 128)
            ..quadraticBezierTo(246, 116, 255, 128),
          _line(7, alpha),
        );
        final cheek = Paint()..color = AdColors.pink.withValues(alpha: .75 * alpha);
        canvas.drawCircle(const Offset(203, 143), 6.5, cheek);
        canvas.drawCircle(const Offset(257, 143), 6.5, cheek);
        canvas.restore();
      case GsMood.worried:
        canvas.save();
        if (!reduced) {
          final a = const CssAnim(.18, infinite: true, curve: cssLinear);
          canvas.translate(a.sample(t, _tremble)!, 0);
        }
        canvas.drawPath(
          Path()
            ..moveTo(203, 109)
            ..lineTo(222, 103)
            ..moveTo(238, 103)
            ..lineTo(257, 109),
          _line(5.5, alpha),
        );
        _eyes(canvas, const Offset(213, 126), const Offset(245, 126), 7, t, alpha);
        canvas.drawPath(
          Path()
            ..moveTo(221, 152)
            ..quadraticBezierTo(230, 147, 239, 152),
          _line(4.5, alpha),
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_APainter old) => true;
}
