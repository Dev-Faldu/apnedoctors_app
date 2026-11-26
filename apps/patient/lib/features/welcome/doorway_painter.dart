import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/brand/living_a.dart';
import '../../core/brand/path_ops.dart';
import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';
import 'welcome_timings.dart';

/// Where the doorway sits in the Welcome hero box (N01Welcome: `svg.arch`, 340 x 372 viewBox,
/// height 100% of the hero up to 372, bottom-centred; the glow is 420 px, 8% above the bottom).
class DoorwayGeometry {
  DoorwayGeometry(Size box, {double extraTop = 0}) {
    heroH = box.height + extraTop;
    var h = math.min(heroH, 372.0);
    if (h * 340 / 372 > box.width - 16) h = (box.width - 16) * 372 / 340;
    k = h / 372;
    arch = Rect.fromLTWH((box.width - 340 * k) / 2, box.height - h, 340 * k, h);
    glowCentre = Offset(box.width / 2, box.height - .08 * heroH - 210);
  }

  late final double heroH;

  /// Scale of the 340 x 372 artwork.
  late final double k;
  late final Rect arch;
  late final Offset glowCentre;

  /// The doorway a's bowl centre and scale, in hero-box coordinates.
  Offset get aBowl => arch.topLeft + Offset(157.7 * k, 260 * k);
  double get aScale => 1.05 * k;
}

/// Paints the glow and the painted doorway with the living a, at time [time] on the Welcome clock.
class DoorwayPainter extends CustomPainter {
  DoorwayPainter({
    required this.time,
    required this.timings,
    required this.reduced,
    required this.compact,
    required this.bubbleText,
    this.extraTop = 0,
    this.away,
  }) : super(repaint: away == null ? time : Listenable.merge([time, away]));

  final ValueListenable<double> time;
  final WelcomeTimings timings;
  final bool reduced;
  final bool compact;
  final TextPainter bubbleText;
  final double extraTop;

  /// While the next screen carries the a away (the walk through the doorway), the doorway is left without it.
  final ValueListenable<double>? away;

  // ---- artwork (viewBox units) ----
  static final _archLine = MeasuredPath(
    Path()
      ..moveTo(46, 362)
      ..lineTo(46, 168)
      ..cubicTo(46, 104, 112, 84, 142, 58)
      ..cubicTo(157, 45, 166, 34, 170, 22)
      ..cubicTo(174, 34, 183, 45, 198, 58)
      ..cubicTo(228, 84, 294, 104, 294, 168)
      ..lineTo(294, 362),
  );
  static final _inside = Path.from(_archLine.path)..close();
  static final _shade = MeasuredPath(_archLine.path.shift(const Offset(3, 4)));
  static final _finialDrop = pathFromOps(const [0, 170, -6, 3, 175, 0, 176, 4, 170, 9, 3, 164, 4, 165, 0, 170, -6, 4]);
  static final _string = Path()
    ..moveTo(74, 96)
    ..quadraticBezierTo(170, 140, 266, 96);
  static final _leaves = [
    for (final (x, y0, y1, y2, y3, d) in const [
      (104.0, 112.0, 122.0, 130.0, 137.0, 0.0),
      (137.0, 122.0, 132.0, 141.0, 148.0, .6),
      (170.0, 125.0, 136.0, 145.0, 153.0, 1.2),
      (203.0, 122.0, 132.0, 141.0, 148.0, 0.0),
      (236.0, 112.0, 122.0, 130.0, 137.0, .6),
    ])
      (
        Path()
          ..moveTo(x, y0)
          ..cubicTo(x - 5, y1, x - 4, y2, x, y3)
          ..cubicTo(x + 4, y2, x + 5, y1, x, y0)
          ..close(),
        Offset(x, y0),
        d,
      ),
  ];
  static const _marigolds = [
    (86.0, 102.0, 8.0, 2.4, AdColors.haldi),
    (120.0, 116.0, 8.5, 2.6, AdColors.marigold),
    (153.0, 123.0, 8.5, 2.6, AdColors.haldi),
    (187.0, 123.0, 8.5, 2.6, AdColors.marigold),
    (220.0, 116.0, 8.5, 2.6, AdColors.haldi),
    (254.0, 102.0, 8.0, 2.4, AdColors.marigold),
  ];
  static final _bubble = Path()
    ..moveTo(196, 154)
    ..relativeLineTo(76, 0)
    ..relativeArcToPoint(const Offset(14, 14), radius: const Radius.circular(14))
    ..relativeLineTo(0, 12)
    ..relativeArcToPoint(const Offset(-14, 14), radius: const Radius.circular(14))
    ..relativeLineTo(-58, 0)
    ..relativeLineTo(-12, 12)
    ..relativeLineTo(1, -12)
    ..relativeLineTo(-7, 0)
    ..relativeArcToPoint(const Offset(-14, -14), radius: const Radius.circular(14))
    ..relativeLineTo(0, -12)
    ..relativeArcToPoint(const Offset(14, -14), radius: const Radius.circular(14))
    ..close();

  /// The a's group origin for its bow and entrance (`transform-box: fill-box; 50% 100%`).
  static const _aOrigin = Offset(167.675, 308.3);

  // ---- motion (N01Welcome keyframes) ----
  static final _bow = Keyframes(
    dim: 4, // rotate deg, translateY, scaleX, scaleY
    offsets: const [0, .04, .10, .16, .24, .55, 1],
    values: const [0, 0, 1, 1, 0, 0, 1, 1, 9, 3, 1, .97, 9, 3, 1, .97, 0, 0, 1, 1, 0, 0, 1.025, 1.025, 0, 0, 1, 1],
    curves: List.filled(7, null),
  );
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
  static final _blink = Keyframes.of(const [(0, 1), (.92, 1), (.95, .08), (1, 1)]);
  static final _happy = Keyframes.of(const [(0, 0), (.06, 0), (.09, 1), (.22, 1), (.26, 0), (1, 0)]);
  static final _sayOut = Keyframes.of(const [(0, 1), (.40, 1), (.46, 0), (1, 0)]);
  static final _peek = Keyframes.of(const [(0, 0), (.25, 4), (.70, 4), (1, 0)]);
  static final _sway = Keyframes.of(const [(0, -1.6), (.5, 1.6), (1, -1.6)]);
  static final _leaf = Keyframes.of(const [(0, -6), (.5, 7), (1, -6)]);
  static final _aIn = Keyframes(
    dim: 4, // opacity, translateY, scaleX, scaleY
    offsets: const [0, .6, 1],
    values: const [0, 40, .8, 1.1, 1, -6, 1.04, .96, 1, 0, 1, 1],
    curves: const [null, null, null],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = timings;
    final g = DoorwayGeometry(size, extraTop: extraTop);

    canvas.save();
    canvas.translate(g.arch.left, g.arch.top);
    canvas.scale(g.k);
    _arch(canvas, t);
    canvas.restore();

    // warm turmeric glow; on the board it is a positioned layer, so it paints over the doorway
    final glowOp = reduced || !w.fromSplash ? 1.0 : _eased(CssAnim(.9, delay: w.glow, curve: cssEase), t);
    if (glowOp > 0) {
      final rect = Rect.fromCenter(center: g.glowCentre, width: 420, height: 420);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: math.sqrt2 / 2, // CSS `circle` = farthest corner
            colors: [
              AdColors.haldi.withValues(alpha: .20 * glowOp),
              AdColors.haldi.withValues(alpha: 0),
            ],
            stops: const [0, .65],
          ).createShader(rect),
      );
    }
  }

  void _arch(Canvas canvas, double t) {
    final w = timings;
    double fadeIn(double dur, double delay) => reduced ? 1 : _eased(CssAnim(dur, delay: delay, curve: cssEase), t);

    // inside of the doorway: warm light
    final inside = fadeIn(.6, w.inside);
    if (inside > 0) {
      canvas.drawPath(
        _inside,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 22), const Offset(0, 362), [
            AdColors.doorwayTop.withValues(alpha: inside),
            AdColors.doorwayBottom.withValues(alpha: inside),
          ]),
      );
    }

    // painted band: an ink shade offset down-right, the vermilion band, then travelling white dots
    double drawn(double delay) => reduced ? 1 : _eased(CssAnim(1.1, delay: delay, curve: const Cubic(.6, 0, .2, 1)), t);
    final shade = drawn(w.shade);
    if (shade > 0) canvas.drawPath(_shade.headLength(1200 * shade), _stroke(AdColors.ink, 27));
    final band = drawn(w.band);
    if (band > 0) canvas.drawPath(_archLine.headLength(1200 * band), _stroke(AdColors.vermilion, 22));
    final dots = fadeIn(.5, w.dots);
    if (dots > 0) {
      final run = reduced
          ? 0.0
          : CssAnim(9, delay: w.dots, infinite: true, fill: Fill.none, curve: cssLinear).progress(t) ?? 0;
      final p = Paint()..color = AdColors.paper.withValues(alpha: dots);
      for (final o in _archLine.dots(13, offset: 130 * run)) {
        canvas.drawCircle(o, 2.3, p);
      }
    }

    // kalash finial
    final fin = reduced
        ? 1.0
        : CssAnim(.5, delay: w.finial, curve: const Cubic(.3, 1.6, .5, 1), fill: Fill.forwards).progress(t);
    if (fin != null) {
      final e = reduced ? 1.0 : const Cubic(.3, 1.6, .5, 1).transform(fin);
      final op = e.clamp(0.0, 1.0);
      if (op > 0) {
        canvas.save();
        canvas.translate(170, 18);
        canvas.scale(.2 + .8 * e);
        canvas.translate(-170, -18);
        canvas.drawPath(_finialDrop, Paint()..color = AdColors.haldi.withValues(alpha: op));
        canvas.drawPath(_finialDrop, _stroke(AdColors.ink.withValues(alpha: op), 2));
        canvas.drawCircle(const Offset(170, 13), 5, Paint()..color = AdColors.vermilion.withValues(alpha: op));
        canvas.drawCircle(const Offset(170, 13), 5, _stroke(AdColors.ink.withValues(alpha: op), 2));
        canvas.restore();
      }
    }

    // marigold toran with mango leaves, swaying
    final toran = fadeIn(.5, w.toran);
    if (toran > 0) {
      final sway = reduced
          ? 0.0
          : (CssAnim(4.6, delay: w.toran, infinite: true, fill: Fill.none, curve: cssEaseInOut).sample(t, _sway) ?? 0);
      if (toran < 1) {
        canvas.saveLayer(const Rect.fromLTRB(40, 70, 300, 175), Paint()..color = Color.fromRGBO(0, 0, 0, toran));
      }
      canvas.save();
      canvas.translate(170, 92);
      canvas.rotate(sway * math.pi / 180);
      canvas.translate(-170, -92);
      canvas.drawPath(_string, _stroke(AdColors.toranString, 2));
      for (final (path, origin, delay) in _leaves) {
        final r = reduced
            ? 0.0
            : CssAnim(3.2, delay: delay, infinite: true, fill: Fill.none, curve: cssEaseInOut).sample(t, _leaf) ?? 0;
        canvas.save();
        canvas.translate(origin.dx, origin.dy);
        canvas.rotate(r * math.pi / 180);
        canvas.translate(-origin.dx, -origin.dy);
        canvas.drawPath(path, Paint()..color = AdColors.green);
        canvas.drawPath(path, _stroke(AdColors.ink, 1.6));
        canvas.restore();
      }
      for (final (x, y, r, _, c) in _marigolds) {
        canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
        canvas.drawCircle(Offset(x, y), r, _stroke(AdColors.ink, 1.6));
      }
      for (final (x, y, _, r, _) in _marigolds) {
        canvas.drawCircle(Offset(x, y), r, Paint()..color = AdColors.toranString);
      }
      canvas.restore();
      if (toran < 1) canvas.restore();
    }

    // "namaste!" bubble (hidden on short screens)
    if (!compact) _say(canvas, t);

    // ground shadow
    final shadow = fadeIn(.4, w.shadow);
    if (shadow > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(162, 352), width: 144, height: 16),
        Paint()..color = AdColors.ink.withValues(alpha: .10 * shadow),
      );
    }

    _a(canvas, t);
  }

  void _say(Canvas canvas, double t) {
    final w = timings;
    double op = 1, ty = 0, s = 1;
    if (!reduced) {
      // sayIn pops it up once; sayOut (same delay, later in the list) owns the opacity from then on
      final inAnim = CssAnim(.4, delay: w.say, curve: const Cubic(.3, 1.4, .5, 1));
      final e = inAnim.curve.transform(inAnim.progress(t)!);
      ty = 8 * (1 - e);
      s = .7 + .3 * e;
      op = t < w.say
          ? 0
          : CssAnim(7, delay: w.say, infinite: true, fill: Fill.none, curve: cssEaseInOut).sample(t, _sayOut)!;
    }
    // the namaste leaves with the a when the next screen carries it away
    op *= 1 - ((away?.value ?? 0) / .12).clamp(0.0, 1.0);
    if (op <= 0) return;
    // origin: 20% 100% of the bubble's box (182..286 x 154..206)
    const origin = Offset(202.8, 206);
    canvas.save();
    canvas.translate(origin.dx, origin.dy + ty);
    canvas.scale(s);
    canvas.translate(-origin.dx, -origin.dy);
    if (op < 1) canvas.saveLayer(const Rect.fromLTRB(178, 150, 290, 210), Paint()..color = Color.fromRGBO(0, 0, 0, op));
    canvas.drawPath(_bubble, Paint()..color = AdColors.white);
    canvas.drawPath(_bubble, _stroke(AdColors.ink, 2)..strokeJoin = StrokeJoin.miter);
    final tp = bubbleText;
    tp.paint(canvas, Offset(233 - tp.width / 2, 180 - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    if (op < 1) canvas.restore();
    canvas.restore();
  }

  void _a(Canvas canvas, double t) {
    final w = timings;
    // entrance
    double op = 1, inTy = 0, inSx = 1, inSy = 1;
    if (!reduced) {
      if (w.fromSplash) {
        op = t >= w.aIn ? ((t - w.aIn) / .01).clamp(0.0, 1.0) : 0;
      } else {
        final a = CssAnim(.7, delay: w.aIn, curve: const Cubic(.3, 1.5, .5, 1), fill: Fill.forwards);
        final p = a.progress(t);
        if (p == null) {
          op = 0;
        } else {
          op = _aIn.at(p, 0, a.curve).clamp(0.0, 1.0);
          inTy = _aIn.at(p, 1, a.curve);
          inSx = _aIn.at(p, 2, a.curve);
          inSy = _aIn.at(p, 3, a.curve);
        }
      }
    }
    if (op <= 0 || (away?.value ?? 0) > 0) return;

    // idle life: bow, look around, blink, happy eyes
    double rot = 0, bowTy = 0, bowSx = 1, bowSy = 1, look = 0, lid = 1, happy = 0, peek = 0;
    if (!reduced) {
      final face = CssAnim(7, delay: w.face, infinite: true, fill: Fill.none, curve: cssEaseInOut);
      final fp = face.progress(t);
      if (fp != null) {
        rot = _bow.at(fp, 0, face.curve);
        bowTy = _bow.at(fp, 1, face.curve);
        bowSx = _bow.at(fp, 2, face.curve);
        bowSy = _bow.at(fp, 3, face.curve);
        look = _look.at(fp, 0, face.curve);
        happy = _happy.at(fp, 0, face.curve);
      }
      lid = CssAnim(4.4, delay: w.lids, infinite: true, fill: Fill.none, curve: cssEase).sample(t, _blink) ?? 1;
      if (w.fromSplash) peek = CssAnim(1.3, delay: w.peek, curve: cssEaseInOut).sample(t, _peek) ?? 0;
    }

    canvas.save();
    canvas.translate(_aOrigin.dx, _aOrigin.dy);
    canvas.translate(0, inTy);
    canvas.scale(inSx, inSy);
    canvas.rotate(rot * math.pi / 180);
    canvas.translate(0, bowTy);
    canvas.scale(bowSx, bowSy);
    canvas.translate(-_aOrigin.dx, -_aOrigin.dy);
    canvas.translate(157.7, 260);
    canvas.scale(1.05);
    if (op < 1) canvas.saveLayer(const Rect.fromLTRB(-70, -70, 90, 70), Paint()..color = Color.fromRGBO(0, 0, 0, op));
    paintLivingA(
      canvas,
      AFace(
        open: 1 - happy,
        happy: happy,
        gaze: Offset(look, peek),
        lid: lid,
        blushStyle: BlushStyle.cheeks,
        happyLift: 15,
      ),
    );
    if (op < 1) canvas.restore();
    canvas.restore();
  }

  static double _eased(CssAnim a, double t) {
    final p = a.progress(t);
    return p == null ? 0 : a.curve.transform(p);
  }

  static Paint _stroke(Color c, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  @override
  bool shouldRepaint(DoorwayPainter old) =>
      old.time != time ||
      old.timings != timings ||
      old.reduced != reduced ||
      old.compact != compact ||
      old.extraTop != extraTop ||
      old.away != away;
}
