import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/brand/living_a.dart';
import '../../core/brand/path_ops.dart';
import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';
import 'opening_choreography.dart';
import 'opening_spec.g.dart';

/// Paints the splash (N00Splash): alpana, the name writing itself, the swash and bindi, the nib,
/// the overlay a and the three loading dots, all at time [time] seconds.
class SplashPainter extends CustomPainter {
  SplashPainter({required this.time, required this.choreography}) : super(repaint: time);

  final ValueListenable<double> time;
  final OpeningChoreography choreography;

  /// After this the splash layer has nothing left to draw.
  static const done = OpeningSpec.swap + .02;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    if (t >= done) return;
    final o = choreography.boardOffset;
    canvas.save();
    canvas.translate(o.dx, o.dy);
    _alpana(canvas, t);
    _word(canvas, t);
    _overlayA(canvas, t);
    canvas.restore();
    _dots(canvas, size, t);
  }

  // ---------------------------------------------------------------- alpana
  static const _ring = CssAnim(.8, delay: .5, curve: Cubic(.2, .8, .2, 1));
  static const _ringOut = CssAnim(.9, delay: .7, curve: Cubic(.2, .8, .2, 1));
  static final _petal = pathFromOps(const [0, 0, 0, 3, 21, -6, 23, -30, 0, -47, 3, -23, -30, -21, -6, 0, 0, 4]);
  static final _small = pathFromOps(const [0, 0, 0, 3, 10, -5, 11, -17, 0, -27, 3, -11, -17, -10, -5, 0, 0, 4]);
  static final _vein = pathFromOps(const [0, 0, -9, 3, 10, -13, 11, -26, 0, -35, 3, -11, -26, -10, -13, 0, -9, 4]);
  static final _petalM = MeasuredPath(_petal);
  static final _veinM = MeasuredPath(_vein);

  static final _dotFrames = Keyframes(
    dim: 2, // opacity, scale
    offsets: const [0, .7, 1],
    values: const [0, 0, 1, 1.25, 1, 1],
    curves: const [null, null, null],
  );

  void _alpana(Canvas canvas, double t) {
    final q = choreography.p(t);
    final op = OpeningTracks.alp.at(q, 0).clamp(0.0, 1.0);
    if (op <= 0) return;
    const cx = OpeningSpec.cx, cy = OpeningSpec.cy;
    final layer = op < 1;
    if (layer) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));
    }
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(OpeningTracks.alp.at(q, 1) * math.pi / 180);
    final sc = OpeningTracks.alp.at(q, 2);
    canvas.scale(sc);
    // canvas origin is now the alpana centre

    _dotRing(canvas, t, _ring, -50, .86, 124, 5.5, AdColors.vermilion, 36);
    _dotRing(canvas, t, _ringOut, 50, .9, 180, 3, AdColors.ink.withValues(alpha: .55), 72);

    for (var i = 0; i < 8; i++) {
      final (d0, fill0, vein0) = OpeningSpec.petals[i];
      canvas.save();
      canvas.rotate(i * 45 * math.pi / 180);
      canvas.translate(0, -132);
      final draw = const CssAnim(.5, curve: Cubic(.4, 0, .2, 1)).copyDelay(d0).eased(t);
      final fill = const CssAnim(.3, curve: cssEase).copyDelay(fill0).eased(t);
      final vein = const CssAnim(.35, curve: cssEaseOut).copyDelay(vein0).eased(t);
      if (fill > 0) {
        canvas.drawPath(_petal, Paint()..color = AdColors.paper.withValues(alpha: fill.clamp(0, 1)));
      }
      if (draw > 0) {
        canvas.drawPath(_petalM.head(draw), _stroke(AdColors.vermilion, 3.4));
      }
      if (vein > 0) {
        canvas.drawPath(_veinM.head(vein), _stroke(AdColors.vermilion, 2));
      }
      canvas.restore();

      final (dot0, red0) = OpeningSpec.petalDots[i];
      canvas.save();
      canvas.rotate((i * 45 + 22.5) * math.pi / 180);
      final pd = const CssAnim(.4, curve: Cubic(.3, 1.5, .5, 1)).copyDelay(dot0);
      _popDot(
        canvas,
        pd,
        t,
        const Offset(0, -130 - 13.5),
        (c, a) => c.drawPath(_small, Paint()..color = AdColors.haldi.withValues(alpha: a)),
        origin: const Offset(0, -130),
      );
      final rd = const CssAnim(.35, curve: Cubic(.3, 1.5, .5, 1)).copyDelay(red0);
      _popDot(
        canvas,
        rd,
        t,
        const Offset(0, -166),
        (c, a) => c.drawCircle(const Offset(0, -166), 3, Paint()..color = AdColors.vermilion.withValues(alpha: a)),
      );
      canvas.restore();
    }
    canvas.restore();
    if (layer) canvas.restore();
  }

  /// `sp-dot`: scales a mark up from its own centre with a little overshoot while it fades in.
  void _popDot(
    Canvas canvas,
    CssAnim anim,
    double t,
    Offset centre,
    void Function(Canvas, double) draw, {
    Offset origin = Offset.zero,
  }) {
    final p = anim.progress(t)!;
    final op = _dotFrames.at(p, 0, anim.curve).clamp(0.0, 1.0);
    final s = _dotFrames.at(p, 1, anim.curve);
    if (op <= 0 || s == 0) return;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(s);
    canvas.translate(-centre.dx + origin.dx, -centre.dy + origin.dy);
    draw(canvas, op);
    canvas.restore();
  }

  /// A ring of painted dots (SVG `stroke-dasharray: 0 L` with round caps), spinning in.
  void _dotRing(
    Canvas canvas,
    double t,
    CssAnim anim,
    double fromDeg,
    double fromScale,
    double r,
    double width,
    Color color,
    int count,
  ) {
    final e = anim.eased(t);
    final op = e.clamp(0.0, 1.0);
    if (op <= 0) return;
    canvas.save();
    canvas.rotate(fromDeg * (1 - e) * math.pi / 180);
    canvas.scale(fromScale + (1 - fromScale) * e);
    // the board rounds the gap to 2 decimals, so a last dot can land just before the start
    final gap = double.parse((2 * math.pi * r / count).toStringAsFixed(2));
    final circ = 2 * math.pi * r;
    final paint = Paint()..color = color.withValues(alpha: color.a * op);
    for (var s = 0.0; s < circ; s += gap) {
      final a = s / r;
      canvas.drawCircle(Offset(r * math.cos(a), r * math.sin(a)), width / 2, paint);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- the name
  static final List<(Path, MeasuredPath, Color, double, double)> _glyphs = [
    for (final g in OpeningSpec.glyphs)
      () {
        final path = pathFromOps(g.ops);
        return (path, MeasuredPath(path), g.red ? AdColors.vermilion : AdColors.ink, g.draw, g.fill);
      }(),
  ];
  static final _swash = () {
    final s = OpeningSpec.swashShape;
    final p = Path()..moveTo(s[0], s[1]);
    for (var i = 2; i < s.length; i += 2) {
      p.lineTo(s[i], s[i + 1]);
    }
    return p..close();
  }();
  static final _swashBounds = _swash.getBounds().inflate(12);
  static final _swashLine = () {
    final c = OpeningSpec.swashCentre;
    return MeasuredPath(
      Path()
        ..moveTo(c[0], c[1])
        ..cubicTo(c[2], c[3], c[4], c[5], c[6], c[7]),
    );
  }();

  static const _fadeWord = CssAnim(.4, delay: OpeningSpec.handoff, curve: Cubic(.4, 0, 1, 1));
  static const _wipe = CssAnim(
    OpeningSpec.writeEnd - OpeningSpec.writeStart,
    delay: OpeningSpec.writeStart,
    curve: OpeningSpec.writeCurve,
  );
  static const _swashDraw = CssAnim(
    OpeningSpec.swashEnd - OpeningSpec.swashStart,
    delay: OpeningSpec.swashStart,
    curve: Cubic(.3, .1, .3, 1),
  );
  static const _bindi = CssAnim(.42, delay: OpeningSpec.swashEnd - .06, curve: Cubic(.3, 1.5, .5, 1));
  static const _nibIn = CssAnim(.18, delay: OpeningSpec.writeStart - .1, curve: cssEase);
  static const _nibOut = CssAnim(.3, delay: OpeningSpec.writeEnd - .05, curve: cssEase, fill: Fill.forwards);

  void _word(Canvas canvas, double t) {
    if (t < OpeningSpec.writeStart - .1) return;
    final op = 1 - _fadeWord.eased(t);
    if (op <= 0) return;
    final layer = op < 1;
    if (layer) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));

    // the letters, drawn then filled, revealed behind a feathered wipe
    const top = OpeningSpec.maskY, bottom = OpeningSpec.maskY + OpeningSpec.maskH;
    final band = Rect.fromLTRB(-200, top, OpeningSpec.boardW + 200, bottom);
    canvas.saveLayer(band, Paint());
    for (final (path, measured, color, draw0, fill0) in _glyphs) {
      final fill = const CssAnim(.4, curve: cssEase).copyDelay(fill0).eased(t);
      final draw = const CssAnim(.6, curve: cssEaseOut).copyDelay(draw0).eased(t);
      if (fill > 0) canvas.drawPath(path, Paint()..color = color.withValues(alpha: fill.clamp(0, 1)));
      if (draw > 0) canvas.drawPath(measured.head(draw), _stroke(color, 1.1));
    }
    final left = OpeningSpec.maskX + OpeningSpec.wipeW * _wipe.eased(t);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(left, 0),
          Offset(left + OpeningSpec.wipeW, 0),
          const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          const [0, OpeningSpec.featherStop, 1],
          TileMode.decal,
        ),
    );
    canvas.restore();

    // one tapered turmeric brushstroke, then the bindi
    final sw = _swashDraw.eased(t);
    if (sw > 0) {
      canvas.saveLayer(_swashBounds, Paint());
      canvas.drawPath(_swash, Paint()..color = AdColors.haldi);
      canvas.drawPath(
        _swashLine.head(sw),
        _stroke(const Color(0xFFFFFFFF), 16)
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }
    _popDot(
      canvas,
      _bindi,
      t,
      const Offset(OpeningSpec.bindiX, OpeningSpec.bindiY),
      (c, a) => c.drawCircle(
        const Offset(OpeningSpec.bindiX, OpeningSpec.bindiY),
        5.5,
        Paint()..color = AdColors.vermilion.withValues(alpha: a),
      ),
    );

    // the gliding turmeric nib
    final nibOp = _nibOut.progress(t) != null ? 1 - _nibOut.eased(t) : _nibIn.eased(t);
    if (nibOp > 0) {
      final x = OpeningSpec.nibFrom + (OpeningSpec.nibTo - OpeningSpec.nibFrom) * _wipe.eased(t);
      const y = OpeningSpec.base - 14;
      canvas.saveLayer(
        Rect.fromCircle(center: Offset(x, y), radius: 10),
        Paint()..color = Color.fromRGBO(0, 0, 0, nibOp),
      );
      canvas.drawCircle(Offset(x, y), 9, Paint()..color = AdColors.haldi.withValues(alpha: .22));
      canvas.drawCircle(Offset(x, y), 4.2, Paint()..color = AdColors.haldi);
      canvas.restore();
    }

    if (layer) canvas.restore();
  }

  // ---------------------------------------------------------------- the a
  void _overlayA(Canvas canvas, double t) {
    final c = choreography;
    final op = c.aOpacity(t);
    if (op <= 0) return;
    final pose = c.aPose(t);
    final pop = c.pop(t);
    canvas.save();
    canvas.translate(pose.bowl.dx, pose.bowl.dy);
    canvas.scale(pose.scale);
    // pop: translate(pre) scale(sx, sy) translate(post), around the bottom of the bowl (0, 53)
    canvas.translate(0, 53 + pop.pre);
    canvas.scale(pop.sx, pop.sy);
    canvas.translate(0, pop.post - 53);
    if (op < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));
    paintLivingA(canvas, c.aFace(t));
    if (op < 1) canvas.restore();
    canvas.restore();
  }

  // ---------------------------------------------------------------- loading dots
  static const _dotsLeave = CssAnim(.3, delay: OpeningSpec.handoff, curve: cssEaseIn);
  static final _pulse = Keyframes(
    dim: 2, // opacity, scale
    offsets: const [0, .5, 1],
    values: const [.25, .8, 1, 1, .25, .8],
    curves: const [null, null, null],
  );
  static const _dotColors = [AdColors.vermilion, AdColors.haldi, AdColors.ink];

  void _dots(Canvas canvas, Size size, double t) {
    if (t < OpeningSpec.dots) return;
    final leave = _dotsLeave.eased(t);
    final groupOp = 1 - leave;
    if (groupOp <= 0) return;
    final cy = size.height - 84 - 4 + 6 * leave;
    for (var i = 0; i < 3; i++) {
      final cx = size.width / 2 + (i - 1) * 20;
      final inA = CssAnim(.3, delay: OpeningSpec.dots + i * .1, curve: cssEase);
      final pulse = CssAnim(
        1.2,
        delay: double.parse((OpeningSpec.dots + .3 + i * .18).toStringAsFixed(2)),
        infinite: true,
        fill: Fill.none,
        curve: cssEaseInOut,
      );
      final pp = pulse.progress(t);
      final op = pp != null ? _pulse.at(pp, 0, pulse.curve) : inA.eased(t);
      final s = pp != null ? _pulse.at(pp, 1, pulse.curve) : 1.0;
      canvas.drawCircle(
        Offset(cx, cy),
        4 * s,
        Paint()..color = _dotColors[i].withValues(alpha: (op * groupOp).clamp(0, 1)),
      );
    }
  }

  static Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  @override
  bool shouldRepaint(SplashPainter old) => old.choreography != choreography || old.time != time;
}

extension on CssAnim {
  CssAnim copyDelay(double d) => CssAnim(duration, delay: d, infinite: infinite, fill: fill, curve: curve);

  /// Eased progress, 0 when the animation has no effect yet.
  double eased(double t) {
    final p = progress(t);
    return p == null ? 0 : curve.transform(p);
  }
}
